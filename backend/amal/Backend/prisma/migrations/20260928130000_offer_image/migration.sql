-- An offer can carry its own card image. Existing offers have none and keep
-- falling back to the restaurant's photo.
ALTER TABLE "food_offers" ADD COLUMN "imageUrl" TEXT NOT NULL DEFAULT '';
