-- Third-party delivery through Delhivery Local, configured per zone.
--
-- Additive only: every existing order gets deliveryProvider = 'own', and a zone
-- with no row in food_zone_delivery_configs keeps using our own riders, so
-- nothing changes until an admin turns a zone on.

-- CreateEnum
CREATE TYPE "DeliveryProvider" AS ENUM ('own', 'delhivery');

-- CreateEnum
CREATE TYPE "ZoneDeliveryMode" AS ENUM ('own', 'delhivery', 'delhivery_then_own', 'own_then_delhivery');

-- CreateEnum
CREATE TYPE "NoRiderPolicy" AS ENUM ('fallback_own', 'cancel_refund', 'notify_admin');

-- CreateEnum
CREATE TYPE "RiderConfirmPolicy" AS ENUM ('on_accept', 'prep_aligned', 'on_ready');

-- AlterTable
ALTER TABLE "food_orders" ADD COLUMN     "deliveryProvider" "DeliveryProvider" NOT NULL DEFAULT 'own';

-- CreateTable
CREATE TABLE "food_zone_delivery_configs" (
    "id" VARCHAR(24) NOT NULL DEFAULT encode(gen_random_bytes(12), 'hex'),
    "zoneId" VARCHAR(24) NOT NULL,
    "mode" "ZoneDeliveryMode" NOT NULL DEFAULT 'own',
    "isEnabled" BOOLEAN NOT NULL DEFAULT false,
    "vehicleMode" VARCHAR(20) NOT NULL DEFAULT '2-wheeler',
    "assignTimeoutMin" INTEGER NOT NULL DEFAULT 10,
    "onNoRider" "NoRiderPolicy" NOT NULL DEFAULT 'notify_admin',
    "confirmPolicy" "RiderConfirmPolicy" NOT NULL DEFAULT 'prep_aligned',
    "defaultPrepMinutes" INTEGER NOT NULL DEFAULT 15,
    "maxFare" DECIMAL(10,2),
    "checkServiceability" BOOLEAN NOT NULL DEFAULT true,
    "pickupOtpEnabled" BOOLEAN NOT NULL DEFAULT false,
    "updatedByAdminId" VARCHAR(24),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "food_zone_delivery_configs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "food_delivery_shipments" (
    "id" VARCHAR(24) NOT NULL DEFAULT encode(gen_random_bytes(12), 'hex'),
    "orderId" VARCHAR(24) NOT NULL,
    "provider" "DeliveryProvider" NOT NULL DEFAULT 'delhivery',
    "providerOrderId" VARCHAR(64),
    "status" VARCHAR(32) NOT NULL DEFAULT 'creating',
    "fulfilmentStatus" VARCHAR(40) NOT NULL DEFAULT 'pending',
    "nextDestination" VARCHAR(20),
    "active" BOOLEAN NOT NULL DEFAULT true,
    "vehicleMode" VARCHAR(20) NOT NULL DEFAULT '2-wheeler',
    "quotedFare" DECIMAL(10,2),
    "finalFare" DECIMAL(10,2),
    "pickupOtp" VARCHAR(8),
    "dropOtp" VARCHAR(8),
    "readyToShip" BOOLEAN NOT NULL DEFAULT false,
    "confirmDueAt" TIMESTAMP(3),
    "confirmedAt" TIMESTAMP(3),
    "riderName" VARCHAR(120),
    "riderPhone" VARCHAR(20),
    "vehicleNumber" VARCHAR(30),
    "vehicleType" VARCHAR(30),
    "riderLat" DOUBLE PRECISION,
    "riderLng" DOUBLE PRECISION,
    "riderLocationAt" TIMESTAMP(3),
    "trackingUrl" TEXT,
    "cancelledAt" TIMESTAMP(3),
    "cancellationReason" TEXT,
    "failureReason" TEXT,
    "lastSyncedAt" TIMESTAMP(3),
    "lastEventAt" TIMESTAMP(3),
    "lastPayload" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "food_delivery_shipments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "food_delivery_provider_events" (
    "id" VARCHAR(24) NOT NULL DEFAULT encode(gen_random_bytes(12), 'hex'),
    "shipmentId" VARCHAR(24),
    "provider" "DeliveryProvider" NOT NULL DEFAULT 'delhivery',
    "providerOrderId" VARCHAR(64),
    "source" VARCHAR(16) NOT NULL,
    "fulfilmentStatus" VARCHAR(40),
    "applied" BOOLEAN NOT NULL DEFAULT false,
    "payload" JSONB NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "food_delivery_provider_events_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "food_zone_delivery_configs_zoneId_key" ON "food_zone_delivery_configs"("zoneId");

-- CreateIndex
CREATE UNIQUE INDEX "food_delivery_shipments_providerOrderId_key" ON "food_delivery_shipments"("providerOrderId");

-- CreateIndex
CREATE INDEX "food_delivery_shipments_orderId_createdAt_idx" ON "food_delivery_shipments"("orderId", "createdAt" DESC);

-- CreateIndex
CREATE INDEX "food_delivery_shipments_active_lastSyncedAt_idx" ON "food_delivery_shipments"("active", "lastSyncedAt");

-- CreateIndex
CREATE INDEX "food_delivery_shipments_active_readyToShip_confirmDueAt_idx" ON "food_delivery_shipments"("active", "readyToShip", "confirmDueAt");

-- CreateIndex
CREATE INDEX "food_delivery_provider_events_providerOrderId_createdAt_idx" ON "food_delivery_provider_events"("providerOrderId", "createdAt" DESC);

-- CreateIndex
CREATE INDEX "food_delivery_provider_events_shipmentId_createdAt_idx" ON "food_delivery_provider_events"("shipmentId", "createdAt" DESC);

-- AddForeignKey
ALTER TABLE "food_zone_delivery_configs" ADD CONSTRAINT "food_zone_delivery_configs_zoneId_fkey" FOREIGN KEY ("zoneId") REFERENCES "food_zones"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "food_delivery_shipments" ADD CONSTRAINT "food_delivery_shipments_orderId_fkey" FOREIGN KEY ("orderId") REFERENCES "food_orders"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "food_delivery_provider_events" ADD CONSTRAINT "food_delivery_provider_events_shipmentId_fkey" FOREIGN KEY ("shipmentId") REFERENCES "food_delivery_shipments"("id") ON DELETE SET NULL ON UPDATE CASCADE;
