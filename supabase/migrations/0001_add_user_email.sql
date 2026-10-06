-- Add email to public.users + auto-fill trigger (fixes Resend 0-emails bug)
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS email TEXT;
UPDATE public.users u SET email = au.email FROM auth.users au WHERE u.id = au.id AND (u.email IS NULL OR u.email = '');
CREATE OR REPLACE FUNCTION public.fill_user_email() RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$ BEGIN UPDATE public.users SET email = (SELECT email FROM auth.users WHERE id = NEW.id) WHERE id = NEW.id; RETURN NEW; END; $$;
DROP TRIGGER IF EXISTS on_user_created_fill_email ON public.users;
CREATE TRIGGER on_user_created_fill_email AFTER INSERT ON public.users FOR EACH ROW EXECUTE FUNCTION public.fill_user_email();
