-- Migration: Auto Profile & Avatar Sync for Google and GitHub OAuth
-- Organization: msm.movin (Est. 2022)

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
  extracted_avatar TEXT;
  extracted_name TEXT;
BEGIN
  -- Google stores image in 'picture' or 'avatar_url'
  -- GitHub stores image in 'avatar_url'
  extracted_avatar := COALESCE(
    new.raw_user_meta_data->>'avatar_url',
    new.raw_user_meta_data->>'picture',
    ''
  );
  
  -- Name resolution
  extracted_name := COALESCE(
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'name',
    new.raw_user_meta_data->>'user_name',
    split_part(new.email, '@', 1)
  );

  INSERT INTO public.profiles (id, email, display_name, avatar_url, updated_at)
  VALUES (
    new.id,
    new.email,
    extracted_name,
    extracted_avatar,
    NOW()
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    display_name = COALESCE(EXCLUDED.display_name, public.profiles.display_name),
    avatar_url = CASE 
      WHEN EXCLUDED.avatar_url <> '' THEN EXCLUDED.avatar_url 
      ELSE public.profiles.avatar_url 
    END,
    updated_at = NOW();

  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger runs whenever a user signs up or signs in (metadata update)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT OR UPDATE ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
