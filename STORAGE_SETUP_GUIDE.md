# 📦 Storage Setup Guide

Complete guide for setting up image storage for the Pet Allergy Scanner app with **user profile pictures** and **pet photos**.

---

## 🎯 Overview

The app supports **two storage buckets**:

1. **`user-images`** - User profile pictures
2. **`pet-images`** - Pet photos

Both support **local storage** (device) and **Supabase Storage** (cloud).

---

## 📂 Storage Structure

### **Local Storage (Current Implementation)**
```
Documents/
├── ProfileImages/          # User profile photos
│   └── {uuid}.jpg         # e.g., 3f2504e0-4f89-11d3-9a0c-0305e82c3301.jpg
└── PetImages/             # Pet photos
    └── {uuid}.jpg
```

### **Supabase Storage (Cloud - Recommended)**
```
user-images/               # Bucket for profile pictures
└── {user_id}/             # Organized by user ID
    └── {uuid}.jpg         # One or more profile images

pet-images/                # Bucket for pet photos
└── {user_id}/             # Organized by user ID
    └── {pet_id}/          # Organized by pet ID
        └── {uuid}.jpg     # Multiple pet photos per pet
```

---

## 🚀 Quick Setup (Supabase Dashboard)

### **Step 1: Create Storage Buckets**

1. Go to **[Supabase Dashboard](https://app.supabase.com)** → Your Project
2. Click **Storage** in left sidebar
3. Click **"New bucket"**

#### **Create User Images Bucket:**
- **Name**: `user-images`
- **Public bucket**: ✅ Yes
- **File size limit**: 5 MB
- **Allowed MIME types**: 
  - `image/jpeg`
  - `image/jpg`
  - `image/png`
  - `image/webp`
- Click **"Create bucket"**

#### **Create Pet Images Bucket:**
- **Name**: `pet-images`
- **Public bucket**: ✅ Yes
- **File size limit**: 5 MB
- **Allowed MIME types**: Same as above
- Click **"Create bucket"**

### **Step 2: Apply Security Policies**

1. Go to **SQL Editor** in Supabase Dashboard
2. Copy the entire contents of `server/database_schemas/supabase_storage_setup.sql`
3. Paste and click **"Run"**

Or via command line:
```bash
psql "postgresql://postgres:[PASSWORD]@[PROJECT-REF].supabase.co:5432/postgres" \
  -f server/database_schemas/supabase_storage_setup.sql
```

### **Step 3: Run Database Migrations**

```bash
# Add image_url columns to database tables
psql "postgresql://postgres:[PASSWORD]@[PROJECT-REF].supabase.co:5432/postgres" \
  -f server/migrations/add_user_image_url.sql

psql "postgresql://postgres:[PASSWORD]@[PROJECT-REF].supabase.co:5432/postgres" \
  -f server/migrations/add_pet_image_url.sql
```

### **Step 4: Configure iOS App**

Add to your `Info.plist`:
```xml
<key>SUPABASE_URL</key>
<string>https://[YOUR-PROJECT-REF].supabase.co</string>

<key>SUPABASE_ANON_KEY</key>
<string>your-anon-key-here</string>

<key>API_BASE_URL</key>
<string>https://[YOUR-PROJECT-REF].supabase.co/api/v1</string>
```

---

## 🔒 Security Policies Explained

### **User Images Policies**

#### **Upload Policy**
```sql
-- Users can only upload to their own folder
(storage.foldername(name))[1] = auth.uid()::text
```
- ✅ User `abc123` can upload to `user-images/abc123/`
- ❌ User `abc123` cannot upload to `user-images/xyz789/`

#### **Read Policy (Authenticated)**
```sql
-- Users can read their own images
bucket_id = 'user-images' AND
(storage.foldername(name))[1] = auth.uid()::text
```
- Users can access their own profile images
- Maintains privacy between users

#### **Public Read Policy**
```sql
-- Anyone can view via public URL
bucket_id = 'user-images'
```
- Allows sharing profile pictures
- Public URLs work without authentication
- Good for: avatars, social features

### **Pet Images Policies**
Same structure as user images but for `pet-images` bucket.

---

## 📱 iOS Implementation

### **Option 1: Local Storage (Current)**

**Pros:**
- ✅ Works offline
- ✅ No external dependencies
- ✅ Fast access
- ✅ No storage costs

**Cons:**
- ❌ Lost on app deletion
- ❌ Not synced across devices
- ❌ Not backed up
- ❌ Single device only

**Code:**
```swift
// Already implemented in AddPetView & EditProfileView
let imageUrl = saveImageLocally(selectedImage)
```

### **Option 2: Supabase Storage (Recommended)**

**Pros:**
- ✅ Cloud backup
- ✅ Cross-device sync
- ✅ CDN delivery (fast)
- ✅ Persistent storage
- ✅ Public URLs for sharing

**Cons:**
- ❌ Requires internet
- ❌ Uses storage quota
- ❌ Upload time

**Code:**
```swift
// Use StorageService
let storageService = StorageService.shared

// Upload profile image
let imageURL = try await storageService.uploadUserImage(
    image: selectedImage,
    userId: currentUser.id
)

// Upload pet image
let imageURL = try await storageService.uploadPetImage(
    image: selectedImage,
    userId: currentUser.id,
    petId: pet.id
)
```

### **Switching from Local to Supabase**

Update `StorageService.swift` to add user image upload:

```swift
/// Upload user profile image to Supabase Storage
func uploadUserImage(image: UIImage, userId: String) async throws -> String {
    isUploading = true
    uploadProgress = 0.0
    errorMessage = nil
    
    defer {
        isUploading = false
        uploadProgress = 0.0
    }
    
    // Optimize image
    uploadProgress = 0.1
    let optimizedResult = try ImageOptimizer.optimizeForUpload(image: image)
    print("📸 User image optimized: \(optimizedResult.summary)")
    
    uploadProgress = 0.3
    
    // Generate filename
    let filename = "\(UUID().uuidString).jpg"
    let filePath = "\(userId)/\(filename)"
    
    uploadProgress = 0.5
    
    // Upload to Supabase Storage
    let uploadedPath = try await uploadFile(
        data: optimizedResult.data,
        path: filePath,
        contentType: "image/jpeg",
        bucket: "user-images"  // User images bucket
    )
    
    uploadProgress = 0.9
    
    // Get public URL
    let publicURL = getPublicURL(path: uploadedPath, bucket: "user-images")
    
    uploadProgress = 1.0
    
    return publicURL
}
```

Then update in `EditProfileView.swift`:

```swift
// Replace saveImageLocally() with:
private func saveProfile() async {
    if let selectedImage = selectedImage, hasImageChanged {
        do {
            let imageURL = try await StorageService.shared.uploadUserImage(
                image: selectedImage,
                userId: authService.currentUser?.id ?? ""
            )
            // Update profile with Supabase URL
            await authService.updateProfile(
                username: username.isEmpty ? nil : username,
                firstName: firstName.isEmpty ? nil : firstName,
                lastName: lastName.isEmpty ? nil : lastName,
                imageUrl: imageURL
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

---

## 💰 Cost Estimation

### **Supabase Free Tier**
- **Storage**: 1 GB
- **Bandwidth**: 2 GB/month
- **File uploads**: Unlimited

### **Cost Calculator**

#### **Scenario: 1000 Users**

**Storage:**
- 1000 users × 1 profile photo × 1.5 MB = 1.5 GB
- 1000 users × 2 pets × 1.5 MB = 3 GB
- **Total: 4.5 GB** → ~**$0.09/month** ($0.021/GB)

**Bandwidth:**
- Profile views: 1000 × 10 views/month × 1.5 MB = 15 GB
- Pet photo views: 2000 × 20 views/month × 1.5 MB = 60 GB
- **Total: 75 GB/month** → ~**$0.67/month** ($0.09/GB over 2GB free)

**Monthly Cost: ~$0.76** 💰

---

## 🔄 Migration from Local to Supabase

If you have existing local images, migrate them:

```swift
/// Migrate local images to Supabase Storage
func migrateImagesToCloud() async {
    let storageService = StorageService.shared
    
    // Migrate user profile image
    if let user = authService.currentUser,
       let localPath = user.imageUrl,
       localPath.hasPrefix("/"),  // Local path
       let localImage = UIImage(contentsOfFile: localPath) {
        
        do {
            let remoteURL = try await storageService.uploadUserImage(
                image: localImage,
                userId: user.id
            )
            
            // Update user with cloud URL
            await authService.updateProfile(
                username: nil,
                firstName: nil,
                lastName: nil,
                imageUrl: remoteURL
            )
            
            // Delete local file
            try? FileManager.default.removeItem(atPath: localPath)
            
            print("✅ User image migrated to cloud")
        } catch {
            print("❌ User image migration failed: \(error)")
        }
    }
    
    // Migrate pet images
    for pet in petService.pets {
        if let localPath = pet.imageUrl,
           localPath.hasPrefix("/"),
           let localImage = UIImage(contentsOfFile: localPath) {
            
            do {
                let remoteURL = try await storageService.uploadPetImage(
                    image: localImage,
                    userId: pet.userId,
                    petId: pet.id
                )
                
                // Update pet with cloud URL
                let update = PetUpdate(imageUrl: remoteURL, ...)
                await petService.updatePet(id: pet.id, petUpdate: update)
                
                // Delete local file
                try? FileManager.default.removeItem(atPath: localPath)
                
                print("✅ Pet \(pet.name) image migrated to cloud")
            } catch {
                print("❌ Pet image migration failed: \(error)")
            }
        }
    }
}
```

---

## 🧪 Testing

### **Test Checklist**

#### **User Profile Pictures**
- [ ] Upload profile picture (camera)
- [ ] Upload profile picture (library)
- [ ] View profile picture on ProfileView
- [ ] Edit/change profile picture
- [ ] Remove profile picture
- [ ] Fallback to person icon when no image
- [ ] Large images get optimized
- [ ] Profile picture persists after app restart

#### **Pet Photos**
- [ ] Upload pet photo (camera)
- [ ] Upload pet photo (library)
- [ ] View pet photo on PetCardView
- [ ] Edit/change pet photo
- [ ] Remove pet photo
- [ ] Fallback to species icon (dog/cat)
- [ ] Large images get optimized
- [ ] Pet photo persists after app restart

#### **Storage Policies**
- [ ] User A cannot access User B's images
- [ ] User A can only upload to their folder
- [ ] Public URLs work without auth
- [ ] Delete removes image from storage

---

## 🐛 Troubleshooting

### **Upload Fails with 403 Error**
**Issue**: Storage policies not applied  
**Solution**: Re-run `supabase_storage_setup.sql`  
**Check**: User is authenticated with valid token

### **Images Not Loading**
**Issue**: Invalid URL or bucket not public  
**Solution**: Verify bucket is set to "public"  
**Check**: URL format: `https://[project].supabase.co/storage/v1/object/public/[bucket]/[path]`

### **Large Upload Times**
**Issue**: Image too large  
**Solution**: Already optimized client-side  
**Check**: Log shows optimization: "Image optimized: X MB → Y MB"

### **Images Disappear After App Delete**
**Issue**: Using local storage  
**Solution**: Migrate to Supabase Storage  
**Check**: URLs should start with `https://` not `/`

---

## 📚 Resources

- [Supabase Storage Documentation](https://supabase.com/docs/guides/storage)
- [Storage Security Policies](https://supabase.com/docs/guides/storage/security/access-control)
- [iOS Image Optimization Best Practices](https://developer.apple.com/documentation/uikit/uiimage)
- [Swift Async/Await Guide](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)

---

## 🎉 Summary

You now have a complete image storage solution:

✅ **Two storage buckets** (user-images, pet-images)  
✅ **Security policies** (RLS protection)  
✅ **Client-side optimization** (auto-compress)  
✅ **Local or cloud storage** (flexible)  
✅ **Elegant fallbacks** (person icon, species icons)  
✅ **Cost-effective** (~$0.76/month for 1000 users)  

Start with **local storage** for development, then migrate to **Supabase Storage** for production! 🚀

