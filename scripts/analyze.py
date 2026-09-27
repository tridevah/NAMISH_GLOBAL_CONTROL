with open('D:/NAMISH_GLOBAL_CONTROL/r16_cli_commit_20260901_203200/supabase/migrations/20260901000004_r16_promotion_commit.sql', 'r') as f:
    content = f.read()

# The structure currently is:
# SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
# SELECT pg_advisory_xact_lock(...);
# SET search_path TO ...;
# SET CONSTRAINTS ALL IMMEDIATE;
# CREATE TEMPORARY TABLE _r16_norm (...) ON COMMIT DROP;
# INSERT INTO _r16_norm ... VALUES ...;  (15,000+ rows)
# ...
# DO  ... ;

# We need ONE big DO block wrapping everything after the SET statements.
# But the INSERT has 15,000+ rows which is fine inside a DO block.
# We need to wrap from CREATE TEMP TABLE to the end in DO  DECLARE BEGIN ... END; ;

# Find where the DO  starts 
do_start = content.find('\nDO \r\n')
if do_start == -1:
    do_start = content.find('\nDO \n')

# Everything before DO  is preamble (SET statements + CREATE TEMP + INSERT)
preamble = content[:do_start]
do_block = content[do_start:]

# Remove the DO  wrapper from the original DO block
# and extract the inner DECLARE...END body
inner_start = do_block.find('DECLARE\r\n') 
if inner_start == -1:
    inner_start = do_block.find('DECLARE\n')
inner_end = do_block.rfind(';') 
inner = do_block[inner_start:inner_end]

# Find the CREATE TEMPORARY TABLE and INSERT statements in the preamble
# Move them inside the DO block
create_temp_start = preamble.find('\nCREATE TEMPORARY TABLE _r16_norm')
create_section = preamble[create_temp_start:]
preamble_only = preamble[:create_temp_start]

# Build new file: SET statements, then one big DO block
new_content = preamble_only.strip() + '\n\n'
new_content += 'DO \n'
new_content += 'DECLARE\n'
new_content += inner[len('DECLARE\r\n'):] if inner.startswith('DECLARE\r\n') else inner[len('DECLARE\n'):]
new_content += ';\n'

# The DO block now has the original DECLARE+BEGIN from the inner block
# But we need the CREATE TEMP TABLE and INSERT to be EXECUTE'd inside PL/pgSQL

# Actually, in PL/pgSQL we can't use CREATE TEMP TABLE directly - wait, YES we can.
# PL/pgSQL supports DDL statements directly without EXECUTE for CREATE TEMP TABLE.
# The issue is the 15k INSERT needs to be inside the DO block.

# Let me just prepend the create temp table and insert into the DO block begin section
# Replace the inner content: find BEGIN and insert CREATE+INSERT after it

begin_marker = 'BEGIN\n'
begin_pos = new_content.find(begin_marker, new_content.find('DO '))
if begin_pos == -1:
    begin_marker = 'BEGIN\r\n'
    begin_pos = new_content.find(begin_marker, new_content.find('DO '))

create_section_cleaned = create_section.strip()

new_content = (new_content[:begin_pos + len(begin_marker)] + 
               '    ' + create_section_cleaned.replace('\n', '\n    ') + '\n\n' +
               new_content[begin_pos + len(begin_marker):])

with open('/tmp/check.sql', 'w') as f:
    f.write(new_content[:2000])
print('New start:')
print(new_content[:1000])
