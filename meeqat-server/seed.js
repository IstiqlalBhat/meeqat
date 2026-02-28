require('dotenv').config();

const { supabase } = require('./db/supabase');

async function seed() {
  // Check if masjid data exists
  const { data: existing } = await supabase
    .from('masjids')
    .select('id')
    .limit(1)
    .maybeSingle();

  if (!existing) {
    const firebaseUid = process.env.SEED_FIREBASE_UID || null;

    const { data: masjid } = await supabase
      .from('masjids')
      .insert({
        name: 'Islamic Center of Clemson',
        address: '103 Islamic Center Dr',
        city: 'Clemson',
        state: 'South Carolina',
        country: 'US',
        latitude: 34.6834,
        longitude: -82.8374,
        calculation_method: 2,
        firebase_uid: firebaseUid
      })
      .select('id')
      .single();

    // Seed Jumu'ah times
    await supabase.from('jumuah_times').insert({
      masjid_id: masjid.id,
      khutbah_time: '13:15',
      first_jamaat: '13:45',
      second_jamaat: null
    });

    // Seed permanent iqamah overrides
    const iqamahTimes = [
      { prayer: 'fajr', iqamah: '06:15' },
      { prayer: 'dhuhr', iqamah: '13:30' },
      { prayer: 'asr', iqamah: '16:30' },
      { prayer: 'isha', iqamah: '20:30' }
    ];

    for (const t of iqamahTimes) {
      await supabase.from('prayer_overrides').insert({
        masjid_id: masjid.id,
        date: null,
        prayer: t.prayer,
        athan_time: null,
        iqamah_time: t.iqamah
      });
    }

    // Seed an announcement
    await supabase.from('announcements').insert({
      masjid_id: masjid.id,
      title: 'Welcome to Meeqat',
      body: 'Stay connected with your local masjid prayer times.'
    });

    console.log('Seeded default masjid and data successfully.');
    if (firebaseUid) {
      console.log(`Assigned to Firebase UID: ${firebaseUid}`);
    } else {
      console.log('No SEED_FIREBASE_UID set - masjid is unassigned. Set it in .env to claim ownership.');
    }
  } else {
    console.log('Database already has data, skipping seed.');
  }
}

seed().catch(err => {
  console.error('Seed error:', err);
  process.exit(1);
});
