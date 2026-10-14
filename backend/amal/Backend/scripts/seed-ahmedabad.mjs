/**
 * Sets up the Ahmedabad zone, ready for Delhivery Local.
 *
 *  - Zone: Ahmedabad city, roughly the area inside the Sardar Patel Ring Road.
 *    Tighten it to Delhivery's Ahmedabad service map when they send it
 *    (Admin → Zone Setup), so customers outside their coverage aren't offered
 *    delivery.
 *  - Fees: what the customer pays per order. Set against Delhivery's typical
 *    2-wheeler quote (~₹40–80 for 0–6 km) so delivery isn't loss-making;
 *    revisit once real quotes come in.
 *  - Delivery: Delhivery only, 2-wheeler, rider released as the food gets
 *    ready, 10 min to find a rider, then retry once and alert an admin.
 *    Left SWITCHED OFF: turn it on in Admin → Delivery Providers once the
 *    Delhivery credentials are in Backend/.env and "Test with Delhivery"
 *    passes.
 *
 * Idempotent: the zone is matched by name; fees and delivery settings are
 * created once and then left alone, so re-running never overwrites what an
 * admin has since changed.
 *
 *   node scripts/seed-ahmedabad.mjs
 */
import 'dotenv/config';
import { prisma } from '../src/config/prisma.js';

const ZONE_NAME = 'Ahmedabad';

// Clockwise from the north, tracing the SP Ring Road.
const ZONE_RING = [
    { latitude: 23.1250, longitude: 72.5750 }, // Zundal / Chandkheda north
    { latitude: 23.1050, longitude: 72.6600 }, // Naroda / Nana Chiloda
    { latitude: 23.0300, longitude: 72.7050 }, // Odhav / Nikol east
    { latitude: 22.9550, longitude: 72.6700 }, // Vatva / Ramol south-east
    { latitude: 22.9350, longitude: 72.5800 }, // Narol / Aslali south
    { latitude: 22.9550, longitude: 72.4900 }, // Sarkhej south-west
    { latitude: 23.0300, longitude: 72.4650 }, // Bopal / Shela west
    { latitude: 23.1000, longitude: 72.4950 }, // Gota / Vaishnodevi north-west
];

const zoneData = {
    name: ZONE_NAME,
    zoneName: ZONE_NAME,
    serviceLocation: 'Ahmedabad, Gujarat',
    coordinates: ZONE_RING,
    isActive: true,
};

const existingZone = await prisma.foodZone.findFirst({ where: { name: ZONE_NAME } });
const zone = existingZone
    ? await prisma.foodZone.update({ where: { id: existingZone.id }, data: zoneData })
    : await prisma.foodZone.create({ data: zoneData });
console.log(`zone: ${zone.name} (${zone.id}) ${existingZone ? 'updated' : 'created'}`);

// Customer fees for the zone.
const fees = await prisma.foodFeeSettings.findFirst({ where: { zoneId: zone.id } });
if (!fees) {
    await prisma.foodFeeSettings.create({
        data: {
            zoneId: zone.id,
            deliveryFee: 49,
            platformFee: 5,
            gstRate: 5,
            isActive: true,
            deliveryFeeBands: {
                create: [
                    // Rider pay is our own fleet's; Delhivery orders pay Delhivery instead.
                    { minDistanceKm: 0, maxDistanceKm: 3, fee: 35, deliveryBoyBasePay: 30 },
                    { minDistanceKm: 3, maxDistanceKm: 6, fee: 49, deliveryBoyBasePay: 45 },
                    { minDistanceKm: 6, maxDistanceKm: 10, fee: 69, deliveryBoyBasePay: 60 },
                ],
            },
        },
    });
    console.log('fees: created (₹35 / ₹49 / ₹69 for 0–3 / 3–6 / 6–10 km, ₹5 platform, 5% GST)');
} else {
    console.log('fees: already configured, left alone');
}

// Delhivery delivery settings — prepared, switched off.
const delivery = await prisma.foodZoneDeliveryConfig.findUnique({ where: { zoneId: zone.id } });
if (!delivery) {
    await prisma.foodZoneDeliveryConfig.create({
        data: {
            zoneId: zone.id,
            mode: 'delhivery',
            isEnabled: false,
            vehicleMode: '2-wheeler',
            assignTimeoutMin: 10,
            onNoRider: 'notify_admin',
            confirmPolicy: 'prep_aligned',
            defaultPrepMinutes: 15,
            maxFare: 120,
            checkServiceability: true,
            pickupOtpEnabled: false,
        },
    });
    console.log('delivery: Delhivery only, 2-wheeler, prep-aligned, ₹120 cap — SWITCHED OFF until credentials work');
} else {
    console.log(`delivery: already configured (mode ${delivery.mode}, ${delivery.isEnabled ? 'on' : 'off'}), left alone`);
}

const restaurants = await prisma.foodRestaurant.count({ where: { zoneId: zone.id } });
console.log(`restaurants in zone: ${restaurants}`);

await prisma.$disconnect();
