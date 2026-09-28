-- Rebrand: Minto Foods -> Amal Foods.
--
-- Same shape as 20260826130000_rebrand_business_settings_defaults: the column
-- default moves, and the settings row is rewritten only while it still carries
-- the old default, so a name an operator chose deliberately is left alone.
ALTER TABLE "food_business_settings" ALTER COLUMN "companyName" SET DEFAULT 'Amal Foods';

UPDATE "food_business_settings" SET "companyName" = 'Amal Foods' WHERE "companyName" = 'Minto Foods';
