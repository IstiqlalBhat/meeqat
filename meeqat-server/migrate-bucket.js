require('dotenv').config();

const { supabase } = require('./db/supabase');

const OLD_BUCKET = 'noor-images';
const NEW_BUCKET = 'meeqat-images';

async function migrateBucket() {
  // 1. Create new bucket
  console.log(`Creating bucket "${NEW_BUCKET}"...`);
  const { error: createErr } = await supabase.storage.createBucket(NEW_BUCKET, { public: true });
  if (createErr) {
    if (createErr.message.includes('already exists')) {
      console.log(`Bucket "${NEW_BUCKET}" already exists, continuing...`);
    } else {
      throw createErr;
    }
  } else {
    console.log(`Bucket "${NEW_BUCKET}" created.`);
  }

  // 2. Copy all files from old bucket to new bucket
  const folders = ['masjids', 'announcements', 'gallery'];
  let copied = 0;

  for (const folder of folders) {
    const { data: files, error: listErr } = await supabase.storage
      .from(OLD_BUCKET)
      .list(folder, { limit: 1000 });

    if (listErr) {
      console.warn(`Could not list ${folder}:`, listErr.message);
      continue;
    }

    if (!files || files.length === 0) {
      console.log(`No files in ${folder}/`);
      continue;
    }

    for (const file of files) {
      if (!file.name || file.id === null) continue; // skip placeholders

      const filePath = `${folder}/${file.name}`;
      console.log(`  Copying ${filePath}...`);

      // Download from old bucket
      const { data: blob, error: dlErr } = await supabase.storage
        .from(OLD_BUCKET)
        .download(filePath);

      if (dlErr) {
        console.warn(`  Failed to download ${filePath}:`, dlErr.message);
        continue;
      }

      // Upload to new bucket
      const buffer = Buffer.from(await blob.arrayBuffer());
      const { error: upErr } = await supabase.storage
        .from(NEW_BUCKET)
        .upload(filePath, buffer, {
          contentType: file.metadata?.mimetype || 'application/octet-stream',
          upsert: true,
        });

      if (upErr) {
        console.warn(`  Failed to upload ${filePath}:`, upErr.message);
        continue;
      }

      copied++;
    }
  }

  console.log(`\nCopied ${copied} file(s) to "${NEW_BUCKET}".`);

  // 3. Update database references (swap old bucket name for new in URLs)
  console.log('\nUpdating database references...');

  const { data: masjidRows } = await supabase.from('masjids').select('id, image_url');
  let updated = 0;

  for (const row of (masjidRows || [])) {
    if (row.image_url && row.image_url.includes(OLD_BUCKET)) {
      const newUrl = row.image_url.replace(OLD_BUCKET, NEW_BUCKET);
      await supabase.from('masjids').update({ image_url: newUrl }).eq('id', row.id);
      updated++;
    }
  }

  const { data: annRows } = await supabase.from('announcements').select('id, image_url');
  for (const row of (annRows || [])) {
    if (row.image_url && row.image_url.includes(OLD_BUCKET)) {
      const newUrl = row.image_url.replace(OLD_BUCKET, NEW_BUCKET);
      await supabase.from('announcements').update({ image_url: newUrl }).eq('id', row.id);
      updated++;
    }
  }

  console.log(`Updated ${updated} database URL(s).`);

  // 4. Delete old bucket contents and bucket
  console.log(`\nDeleting old bucket "${OLD_BUCKET}"...`);

  for (const folder of folders) {
    const { data: files } = await supabase.storage
      .from(OLD_BUCKET)
      .list(folder, { limit: 1000 });

    if (files && files.length > 0) {
      const paths = files.filter(f => f.name && f.id !== null).map(f => `${folder}/${f.name}`);
      if (paths.length > 0) {
        await supabase.storage.from(OLD_BUCKET).remove(paths);
      }
    }
  }

  const { error: deleteErr } = await supabase.storage.deleteBucket(OLD_BUCKET);
  if (deleteErr) {
    console.warn(`Could not delete old bucket: ${deleteErr.message}`);
    console.log('You may need to delete it manually from the Supabase dashboard.');
  } else {
    console.log(`Old bucket "${OLD_BUCKET}" deleted.`);
  }

  console.log('\nDone! Bucket migration complete.');
}

migrateBucket().catch(err => {
  console.error('Migration failed:', err);
  process.exit(1);
});
