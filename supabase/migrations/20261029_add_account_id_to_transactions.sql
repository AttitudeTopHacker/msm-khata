-- Add Multi-Book / Multi-Account support to transactions
ALTER TABLE public.transactions ADD COLUMN IF NOT EXISTS account_id TEXT DEFAULT 'main';
ALTER TABLE public.transactions ADD COLUMN IF NOT EXISTS account_name TEXT DEFAULT 'Main Account';
CREATE INDEX IF NOT EXISTS idx_transactions_account ON public.transactions(account_id);
