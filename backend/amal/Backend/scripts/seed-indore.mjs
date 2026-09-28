/**
 * Seeds the Indore zone with demo restaurants, categories and dishes.
 *
 * Everything goes through the same paths as seed-demo-restaurant.mjs:
 * deriveRestaurantFields and fromRestaurantLocation build the restaurant row so
 * name search and the PostGIS radius queries see it, and the zone is written as
 * a `coordinates` ring that the zone_boundary_sync trigger turns into a polygon.
 *
 * Idempotent: the zone is matched by name, restaurants by their unique
 * name + phone pair, categories by name within the zone, dishes by name within
 * the restaurant. Re-running updates in place.
 *
 *   node scripts/seed-indore.mjs
 */
import 'dotenv/config';
import { prisma } from '../src/config/prisma.js';
import { deriveRestaurantFields, fromRestaurantLocation } from '../src/modules/food/restaurant/restaurant.mapper.js';

const ZONE_NAME = 'Indore';

// Covers the city from Rau in the south-west to the Bypass in the east.
const ZONE_RING = [
    { latitude: 22.62, longitude: 75.76 },
    { latitude: 22.62, longitude: 75.98 },
    { latitude: 22.82, longitude: 75.98 },
    { latitude: 22.82, longitude: 75.76 },
];

const DAYS = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

const RESTAURANTS = [
    {
        name: 'Sarafa Chaat Corner', phone: '9000000101', veg: true,
        area: 'Sarafa Bazaar', address: 'Sarafa Bazaar, Rajwada', pincode: '452002',
        lat: 22.7179, lng: 75.8560, cuisines: ['Street Food', 'Chaat'],
        open: '17:00', close: '23:59', eta: '20-25 mins', rating: 4.6, ratings: 842,
        menu: {
            'Street Food': [
                ['Bhutte ka Kees', 80, 'Grated corn cooked in milk and spices, an Indori classic'],
                ['Garadu', 90, 'Fried yam cubes tossed in chaat masala and lemon'],
                ['Khopra Pattice', 60, 'Potato patties stuffed with coconut and dry fruits'],
                ['Dahi Bada', 70, 'Soft lentil dumplings in sweet curd with chutneys'],
            ],
            Desserts: [
                ['Jalebi (250 g)', 60, 'Hot, crisp jalebi fried to order'],
                ['Malpua with Rabdi', 110, 'Sweet pancakes served with thick rabdi'],
            ],
        },
    },
    {
        name: 'Poha Junction', phone: '9000000102', veg: true,
        area: 'Rajwada', address: 'Near Rajwada Palace', pincode: '452004',
        lat: 22.7187, lng: 75.8551, cuisines: ['Breakfast', 'Street Food'],
        open: '06:30', close: '14:00', eta: '15-20 mins', rating: 4.5, ratings: 1203,
        menu: {
            Breakfast: [
                ['Indori Poha', 40, 'Steamed poha with jeeravan, sev and pomegranate'],
                ['Poha Jalebi Combo', 70, 'The Indore breakfast: poha with hot jalebi'],
                ['Usal Poha', 60, 'Poha topped with spicy sprout usal'],
                ['Sabudana Khichdi', 60, 'Sago with peanuts and green chilli'],
            ],
            Beverages: [
                ['Masala Chai', 20, 'Strong tea with ginger and cardamom'],
                ['Cold Coffee', 70, 'Thick cold coffee with ice cream'],
            ],
        },
    },
    {
        name: 'Vijay Nagar Biryani House', phone: '9000000103', veg: false,
        area: 'Vijay Nagar', address: 'Scheme 54, Vijay Nagar', pincode: '452010',
        lat: 22.7533, lng: 75.8937, cuisines: ['Biryani', 'Mughlai'],
        open: '11:00', close: '23:30', eta: '30-35 mins', rating: 4.4, ratings: 657,
        menu: {
            Biryani: [
                ['Chicken Dum Biryani', 260, 'Slow-cooked basmati and chicken, sealed dum style', 'NonVeg'],
                ['Mutton Biryani', 340, 'Tender mutton layered with saffron rice', 'NonVeg'],
                ['Egg Biryani', 190, 'Spiced rice with boiled eggs', 'NonVeg'],
                ['Veg Dum Biryani', 190, 'Seasonal vegetables and paneer in dum rice'],
            ],
            Sides: [
                ['Chicken 65', 220, 'Crisp spicy fried chicken', 'NonVeg'],
                ['Boondi Raita', 50, 'Chilled curd with boondi'],
            ],
        },
    },
    {
        name: 'Palasia Pizza Co.', phone: '9000000104', veg: true,
        area: 'Palasia', address: 'AB Road, New Palasia', pincode: '452001',
        lat: 22.7244, lng: 75.8839, cuisines: ['Pizza', 'Italian'],
        open: '11:00', close: '23:00', eta: '25-30 mins', rating: 4.2, ratings: 389,
        menu: {
            Pizza: [
                ['Margherita Pizza', 199, 'Tomato sauce, mozzarella and basil'],
                ['Farmhouse Pizza', 289, 'Onion, capsicum, tomato and mushroom'],
                ['Paneer Tikka Pizza', 319, 'Tandoori paneer, onion and mint mayo'],
                ['Corn & Cheese Pizza', 249, 'Sweet corn with double cheese'],
            ],
            Sides: [
                ['Garlic Bread', 119, 'Toasted garlic bread with herbs'],
                ['White Sauce Pasta', 179, 'Penne in creamy white sauce'],
            ],
        },
    },
    {
        name: 'Malwa Thali Ghar', phone: '9000000105', veg: true,
        area: 'Bhawarkua', address: 'Bhawarkua Square', pincode: '452001',
        lat: 22.6937, lng: 75.8676, cuisines: ['Thali', 'Malwi'],
        open: '11:00', close: '22:30', eta: '30-35 mins', rating: 4.5, ratings: 511,
        menu: {
            Thali: [
                ['Malwa Special Thali', 249, 'Dal bafla, kadhi, two sabzi, rice, salad and laddoo'],
                ['Dal Bafla (2 pcs)', 149, 'Baked wheat bafla with ghee and dal'],
                ['Mini Thali', 159, 'Dal, sabzi, rice and three rotis'],
            ],
            'North Indian': [
                ['Kadhi Pakoda', 129, 'Tangy curd kadhi with pakodas'],
                ['Sev Tamatar', 139, 'Indori sev in a tomato gravy'],
            ],
            Desserts: [['Churma Laddoo (2 pcs)', 60, 'Wheat and jaggery laddoo in ghee']],
        },
    },
    {
        name: '56 Street Burgers', phone: '9000000106', veg: false,
        area: '56 Dukan', address: '56 Dukan, New Palasia', pincode: '452001',
        lat: 22.7236, lng: 75.8812, cuisines: ['Burgers', 'Fast Food'],
        open: '12:00', close: '23:59', eta: '20-25 mins', rating: 4.3, ratings: 724,
        menu: {
            Burgers: [
                ['Aloo Tikki Burger', 79, 'Crisp potato patty with mint mayo'],
                ['Paneer Crunch Burger', 139, 'Fried paneer with spicy sauce'],
                ['Chicken Zinger Burger', 169, 'Crunchy chicken fillet with lettuce', 'NonVeg'],
                ['Veg Hot Dog', 89, 'Soft bun, veg sausage and mustard'],
            ],
            Sides: [['Peri Peri Fries', 99, 'Fries with peri peri seasoning']],
            Beverages: [['Oreo Shake', 129, 'Thick shake with crushed Oreo']],
        },
    },
    {
        name: 'Tandoor Nights', phone: '9000000107', veg: false,
        area: 'Sapna Sangeeta', address: 'Sapna Sangeeta Road', pincode: '452001',
        lat: 22.7045, lng: 75.8732, cuisines: ['North Indian', 'Tandoor'],
        open: '12:00', close: '23:30', eta: '30-40 mins', rating: 4.4, ratings: 468,
        menu: {
            'North Indian': [
                ['Butter Chicken', 340, 'Tandoori chicken in a rich tomato butter gravy', 'NonVeg'],
                ['Paneer Butter Masala', 260, 'Paneer in creamy makhani gravy'],
                ['Dal Makhani', 220, 'Black lentils slow-cooked overnight'],
                ['Tandoori Chicken (Half)', 280, 'Chargrilled chicken with mint chutney', 'NonVeg'],
                ['Paneer Tikka', 240, 'Marinated paneer grilled in the tandoor'],
            ],
            Breads: [
                ['Butter Naan', 60, 'Soft naan brushed with butter'],
                ['Tandoori Roti', 25, 'Whole wheat roti from the tandoor'],
            ],
        },
    },
    {
        name: 'Dragon Wok', phone: '9000000108', veg: false,
        area: 'Scheme 94', address: 'Ring Road, Scheme 94', pincode: '452010',
        lat: 22.7520, lng: 75.8990, cuisines: ['Chinese'],
        open: '12:00', close: '23:00', eta: '25-30 mins', rating: 4.1, ratings: 297,
        menu: {
            Chinese: [
                ['Veg Hakka Noodles', 159, 'Wok-tossed noodles with vegetables'],
                ['Veg Manchurian (Gravy)', 179, 'Vegetable balls in Manchurian sauce'],
                ['Chilli Chicken (Dry)', 239, 'Chicken tossed with peppers and soy', 'NonVeg'],
                ['Chicken Fried Rice', 199, 'Egg and chicken fried rice', 'NonVeg'],
                ['Veg Spring Rolls', 139, 'Crisp rolls with sweet chilli dip'],
            ],
        },
    },
];

// ── Zone ────────────────────────────────────────────────────────────────────
const zoneData = {
    name: ZONE_NAME,
    zoneName: ZONE_NAME,
    serviceLocation: 'Indore, Madhya Pradesh',
    coordinates: ZONE_RING,
    isActive: true,
};
const existingZone = await prisma.foodZone.findFirst({ where: { name: ZONE_NAME } });
const zone = existingZone
    ? await prisma.foodZone.update({ where: { id: existingZone.id }, data: zoneData })
    : await prisma.foodZone.create({ data: zoneData });
console.log(`zone: ${zone.name} (${zone.id})`);

// ── Fees for the zone, so checkout can price a delivery ─────────────────────
const existingFees = await prisma.foodFeeSettings.findFirst({ where: { zoneId: zone.id } });
if (!existingFees) {
    await prisma.foodFeeSettings.create({
        data: {
            zoneId: zone.id,
            deliveryFee: 30,
            platformFee: 5,
            gstRate: 5,
            isActive: true,
            deliveryFeeBands: {
                create: [
                    { minDistanceKm: 0, maxDistanceKm: 3, fee: 20, deliveryBoyBasePay: 25 },
                    { minDistanceKm: 3, maxDistanceKm: 6, fee: 35, deliveryBoyBasePay: 40 },
                    { minDistanceKm: 6, maxDistanceKm: 15, fee: 55, deliveryBoyBasePay: 60 },
                ],
            },
        },
    });
    console.log('fees: created for zone');
} else {
    console.log('fees: already configured, left alone');
}

// ── Categories, global ──────────────────────────────────────────────────────
// Global rather than scoped to the zone: the home rail asks for categories
// before it knows the customer's zone, and a zone-scoped category is invisible
// to that request, so the rail came back empty.
const categoryNames = [...new Set(RESTAURANTS.flatMap((r) => Object.keys(r.menu)))];
const categories = new Map();
for (const [index, name] of categoryNames.entries()) {
    const fields = { zoneId: null, isApproved: true, approvalStatus: 'approved', isActive: true, sortOrder: index };
    const found = await prisma.foodCategory.findFirst({ where: { name, restaurantId: null } });
    const category = found
        ? await prisma.foodCategory.update({ where: { id: found.id }, data: fields })
        : await prisma.foodCategory.create({ data: { name, ...fields } });
    categories.set(name, category);
}
console.log(`categories: ${categories.size}`);

// ── Restaurants and dishes ──────────────────────────────────────────────────
let itemCount = 0;
for (const r of RESTAURANTS) {
    const derived = deriveRestaurantFields({
        restaurantName: r.name,
        ownerPhone: r.phone,
        estimatedDeliveryTime: r.eta,
    });
    const location = fromRestaurantLocation({
        latitude: r.lat,
        longitude: r.lng,
        formattedAddress: `${r.address}, Indore, Madhya Pradesh ${r.pincode}`,
        addressLine1: r.address,
        area: r.area,
        city: 'Indore',
        state: 'Madhya Pradesh',
        pincode: r.pincode,
    });
    const [featuredDish, featuredPrice] = Object.values(r.menu)[0][0];

    const data = {
        restaurantName: r.name,
        ownerName: `${r.name} Owner`,
        ownerEmail: `owner${r.phone.slice(-3)}@example.com`,
        ownerPhone: r.phone,
        primaryContactNumber: r.phone,
        ...derived,
        ...location,
        zoneId: zone.id,
        cuisines: r.cuisines,
        openingTime: r.open,
        closingTime: r.close,
        openDays: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
        pureVegRestaurant: r.veg,
        isAcceptingOrders: true,
        estimatedDeliveryTime: r.eta,
        featuredDish,
        featuredPrice,
        rating: r.rating,
        totalRatings: r.ratings,
        status: 'approved',
        approvedAt: new Date(),
    };

    const restaurant = await prisma.foodRestaurant.upsert({
        where: {
            restaurantNameNormalized_ownerPhoneLast10: {
                restaurantNameNormalized: derived.restaurantNameNormalized,
                ownerPhoneLast10: derived.ownerPhoneLast10,
            },
        },
        create: data,
        update: data,
    });

    const timings = DAYS.map((day) => ({ day, isOpen: true, openingTime: r.open, closingTime: r.close }));
    await prisma.foodRestaurantOutletTimings.upsert({
        where: { restaurantId: restaurant.id },
        create: { restaurantId: restaurant.id, timings },
        update: { timings },
    });

    for (const [categoryName, dishes] of Object.entries(r.menu)) {
        const category = categories.get(categoryName);
        for (const [index, [name, price, description, foodType = 'Veg']] of dishes.entries()) {
            const payload = {
                restaurantId: restaurant.id,
                name,
                description,
                price,
                categoryId: category.id,
                categoryName,
                foodType,
                isAvailable: true,
                isRecommended: index === 0,
                approvalStatus: 'approved',
            };
            const found = await prisma.foodItem.findFirst({ where: { restaurantId: restaurant.id, name } });
            if (found) await prisma.foodItem.update({ where: { id: found.id }, data: payload });
            else await prisma.foodItem.create({ data: payload });
            itemCount += 1;
        }
    }
    console.log(`restaurant: ${restaurant.restaurantName} (${r.area})`);
}
console.log(`done: ${RESTAURANTS.length} restaurants, ${itemCount} dishes`);

await prisma.$disconnect();
