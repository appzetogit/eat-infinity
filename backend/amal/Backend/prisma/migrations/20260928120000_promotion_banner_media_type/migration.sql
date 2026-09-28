-- Home promotion banners can be a short video as well as an image.
-- Existing rows are all images, which the default covers.
ALTER TABLE "food_home_promotion_banners" ADD COLUMN "mediaType" TEXT NOT NULL DEFAULT 'image';
