import re

filepath = 'src/app/api/data-hub/units/route.ts'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace in POST
old_post_23505 = "if (error.code === '23505') { // unique_violation\n                return NextResponse.json({ error: 'A unit with that canonical code already exists.' }, { status: 409 })\n            }"
new_post_23505 = "if (error.code === '23505') {\n                return NextResponse.json(\n                    { error: 'This business unit already exists.' },\n                    { status: 409 }\n                )\n            }"

if old_post_23505 in content:
    content = content.replace(old_post_23505, new_post_23505)
else:
    print("Could not find POST 23505 block. Falling back to regex.")
    content = re.sub(
        r"if \(error\.code === '23505'\) \{\s*// unique_violation\s*return NextResponse\.json\(\{ error: 'A unit with that canonical code already exists\.' \}, \{ status: 409 \}\)\s*\}",
        "if (error.code === '23505') {\n                return NextResponse.json(\n                    { error: 'This business unit already exists.' },\n                    { status: 409 }\n                )\n            }",
        content
    )

# Add to PATCH
# Find the exact location in PATCH to insert.
patch_error_block_regex = r"if \(error\.code === 'P0002'\) \{ // RPC raises this on NOT FOUND\s*return NextResponse\.json\(\{ error: 'Business unit not found\.' \}, \{ status: 404 \}\)\s*\}"
new_patch_23505 = "if (error.code === '23505') {\n                return NextResponse.json(\n                    { error: 'This business unit already exists.' },\n                    { status: 409 }\n                )\n            }\n            "

if "error: 'This business unit already exists.'" not in content.split("export async function PATCH")[1]:
    content = re.sub(
        patch_error_block_regex,
        f"\\g<0>\n            {new_patch_23505}",
        content
    )

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated route.ts successfully.")
