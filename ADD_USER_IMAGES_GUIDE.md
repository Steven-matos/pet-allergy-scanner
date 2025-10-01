# 🚀 Quick Guide: Add User Profile Pictures Storage

Since you already have pet-images storage set up, this guide adds **user profile picture** storage.

---

## ⚡ Quick Setup (5 minutes)

### **Step 1: Create `user-images` Bucket**

1. Open **[Supabase Dashboard](https://app.supabase.com)** → Your Project
2. Click **Storage** in left sidebar
3. Click **"New bucket"** button
4. Configure:
   - **Name**: `user-images`
   - **Public bucket**: ✅ Check this box
   - **File size limit**: `5242880` (5MB)
   - **Allowed MIME types**: Click "Add MIME type" for each:
     - `image/jpeg`
     - `image/jpg`
     - `image/png`
     - `image/webp`
5. Click **"Create bucket"**

### **Step 2: Add Storage Policies (Dashboard Method)**

1. In Supabase Dashboard, go to **Storage** → **Policies**
2. Select the **`user-images`** bucket
3. Click **"New Policy"** and add these **5 policies**:

#### **Policy 1: Upload**
- **Name**: `Users can upload their profile image`
- **Allowed operation**: INSERT
- **Target roles**: authenticated
- **Policy definition**:
```sql
bucket_id = 'user-images' AND (storage.foldername(name))[1] = auth.uid()::text
```

#### **Policy 2: View (Authenticated)**
- **Name**: `Users can view their profile image`
- **Allowed operation**: SELECT
- **Target roles**: authenticated
- **Policy definition**:
```sql
bucket_id = 'user-images' AND (storage.foldername(name))[1] = auth.uid()::text
```

#### **Policy 3: Update**
- **Name**: `Users can update their profile image`
- **Allowed operation**: UPDATE
- **Target roles**: authenticated
- **Policy definition**:
```sql
bucket_id = 'user-images' AND (storage.foldername(name))[1] = auth.uid()::text
```

#### **Policy 4: Delete**
- **Name**: `Users can delete their profile image`
- **Allowed operation**: DELETE
- **Target roles**: authenticated
- **Policy definition**:
```sql
bucket_id = 'user-images' AND (storage.foldername(name))[1] = auth.uid()::text
```

#### **Policy 5: Public View**
- **Name**: `Public can view user profile images`
- **Allowed operation**: SELECT
- **Target roles**: public
- **Policy definition**:
```sql
bucket_id = 'user-images'
```

### **Step 3: Run Database Migration (SQL Editor)**

1. Go to **SQL Editor** in Supabase Dashboard
2. Click **"New query"**
3. Copy and paste this:

```sql
-- Add image_url column to users table
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS image_url TEXT;

-- Add comment
COMMENT ON COLUMN users.image_url IS 'URL or file path to user profile photo';
```

4. Click **"Run"**

### **Step 4: Verify Setup**

Run this query in SQL Editor to verify:

```sql
-- Check that both buckets exist
SELECT id, name, public 
FROM storage.buckets 
WHERE id IN ('user-images', 'pet-images');

-- Check that user image column was added
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'users' 
  AND column_name = 'image_url';

-- Check storage policies
SELECT policyname, cmd 
FROM pg_policies 
WHERE tablename = 'objects' 
  AND policyname LIKE '%profile%';
```

Expected results:
- ✅ 2 buckets (user-images, pet-images)
- ✅ 1 column (users.image_url)
- ✅ 5 policies for user images

---

## 🎯 Alternative: SQL Editor Method

If you prefer to use SQL Editor for everything:

1. **Open** Supabase Dashboard → **SQL Editor**
2. **Copy** contents of `server/database_schemas/user_images_storage_policies.sql`
3. **Paste** into SQL Editor
4. **Run** the query

This creates all 5 policies for user-images in one go!

---

## ✅ That's It!

Once complete, your app will have:
- 👤 **User profile pictures** with fallback to person icon
- 🐕 **Pet photos** with fallback to species icons
- ☁️ **Cloud storage** (synced across devices)
- 🔒 **Secure policies** (users can only access their own images)
- 🌐 **Public URLs** (for sharing)

---

## 🧪 Test It

1. Open the app
2. Go to **Profile** tab
3. Tap **"Edit Profile"**
4. Tap the circle at top
5. Choose "Camera" or "Photo Library"
6. Select/take a photo
7. Tap **"Save"**
8. ✅ Your profile picture appears!

Same process works for pet photos in the **Pets** tab.

---

## 💡 Pro Tip

The SQL script now uses `DROP POLICY IF EXISTS` so you can re-run it anytime to refresh policies, but **Supabase requires these to be run via the SQL Editor**, not via external psql connections due to permission restrictions on the storage schema.

