#!/usr/bin/env bash
set -Eeuo pipefail

echo -n "Enter superadmin email: "
read -r EMAIL
echo -n "Enter superadmin password (will be hidden): "
read -rs PASSWORD
echo ""
echo -n "Enter first name: "
read -r FIRST_NAME
echo -n "Enter last name: "
read -r LAST_NAME

echo "Creating user $EMAIL..."
# Do not print password or token
npx supabase db query --linked "
  WITH new_user AS (
    INSERT INTO auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
    ) VALUES (
      '00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', '$EMAIL', crypt('$PASSWORD', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()
    ) RETURNING id
  )
  INSERT INTO platform.platform_staff (id, email, first_name, last_name, role)
  SELECT id, '$EMAIL', '$FIRST_NAME', '$LAST_NAME', 'PLATFORM_SUPERADMIN'
  FROM new_user;
" > /dev/null

echo "Bootstrap complete."
