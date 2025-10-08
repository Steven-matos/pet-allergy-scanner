# Pet Allergy Scanner - Data Standardizor

This folder contains the essential script for standardizing nutritional_info data across all database records.

## 📁 **File Structure**

### **Core Standardization Script**

#### `update_nutritional_info.py` ⭐ **MAIN SCRIPT**
- **Purpose**: Standardizes nutritional_info structure for ALL database records using JSONL data
- **Input**: `../importing/openpetfoodfacts-products.jsonl`
- **Features**:
  - Ensures every record has complete, standardized structure
  - Uses raw JSONL data as reference for external_id matches
  - Extracts nutritional data from JSONL nutriments field
  - Applies appropriate default values (null, [], '', {})
  - Prevents frontend null reference errors
  - 22 standardized properties for every record
  - Processes all 11,467 database records

## 🚀 **Usage**

### **Standardize All Records**
```bash
# Ensure ALL records have complete, standardized nutritional_info structure
python3 update_nutritional_info.py
```

This single script will:
- Load JSONL data from `../importing/openpetfoodfacts-products.jsonl`
- Process all 11,467 database records
- Standardize nutritional_info structure for every record
- Apply appropriate defaults for missing data
- Update database with complete structure

## 🔧 **Environment Setup**

Ensure your `.env` file contains:
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```

## 📊 **Data Quality**

After standardization, your database will have:
- ✅ **11,467 total records** with standardized structure
- ✅ **22 properties** in every nutritional_info field
- ✅ **Consistent structure** across all records
- ✅ **Appropriate defaults** for missing data
- ✅ **No null reference errors** for frontend

## 🎯 **Key Features**

- **Complete Standardization**: Every record has 22 properties
- **JSONL Data Integration**: Uses raw nutritional data where available
- **Default Value Handling**: Appropriate defaults for missing data
- **Frontend Safety**: No null reference errors
- **Database Consistency**: Same schema across all records

## 📝 **Notes**

- Uses Supabase REST API for database operations
- Service role key required for write operations
- Processes all records in batches for performance
- Progress tracking included for long operations
- Error handling and logging throughout

## 📚 **Documentation**

- `NUTRITIONAL_INFO_API_REFERENCE.md` - **Complete frontend reference** for nutritional_info structure
- `README.md` - This file
