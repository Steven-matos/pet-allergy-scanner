# Pet Food Data Import Scripts

This directory contains the essential scripts for importing pet food data from JSONL files into the database.

## 📁 **Essential Files**

### **Core Import Scripts**
- **`import_no_duplicates.py`** - Main import script with duplicate prevention and resume functionality
- **`analyze_skipped_products.py`** - Diagnostic tool to analyze why products are skipped during import
- **`count_products.py`** - Utility to count products in JSONL files

### **Data Files**
- **`openpetfoodfacts-products.jsonl`** - Pet food product data (150MB)

### **Documentation**
- **`FULL_IMPORT_GUIDE.md`** - Complete guide for running imports
- **`README.md`** - This file

## 🚀 **Quick Start**

### **1. Count Products in JSONL File**
```bash
python3 count_products.py
```

### **2. Analyze Why Products Are Skipped**
```bash
python3 analyze_skipped_products.py
```

### **3. Import Data (No Duplicates)**
```bash
python3 import_no_duplicates.py
```

## 📊 **Import Features**

- ✅ **Duplicate Prevention** - Checks existing barcodes and external IDs
- ✅ **Resume Functionality** - Can restart from where it left off
- ✅ **Progress Tracking** - Real-time progress updates
- ✅ **Error Handling** - Graceful handling of database errors
- ✅ **Data Validation** - Ensures data quality before import
- ✅ **Constraint Handling** - Handles database constraint violations

## 🔧 **Requirements**

- Python 3.7+
- `psycopg2-binary`
- `python-dotenv`
- PostgreSQL database connection

## 📝 **Usage Examples**

### **Basic Import**
```bash
python3 import_no_duplicates.py
```

### **Import with Custom Batch Size**
```bash
python3 import_no_duplicates.py --batch-size 1000
```

### **Resume from Specific Line**
```bash
python3 import_no_duplicates.py --start-line 5000
```

### **Analyze Import Issues**
```bash
python3 analyze_skipped_products.py
```

## 🎯 **Best Practices**

1. **Always run analysis first** to understand data quality
2. **Use the main import script** (`import_no_duplicates.py`) for production
3. **Monitor progress** during long imports
4. **Check logs** for any issues or errors
5. **Verify results** after import completion

## 📈 **Performance**

- **Batch Processing** - Processes data in configurable batches
- **Memory Efficient** - Handles large files without memory issues
- **Database Optimized** - Uses efficient database operations
- **Resume Capable** - Can restart interrupted imports

## 🛠️ **Troubleshooting**

### **Common Issues**
- **Connection Errors** - Check database credentials in `.env`
- **Constraint Violations** - Run analysis script to identify issues
- **Memory Issues** - Reduce batch size
- **Duplicate Errors** - Script automatically handles duplicates

### **Getting Help**
1. Run `analyze_skipped_products.py` to diagnose issues
2. Check the logs for specific error messages
3. Verify database connection and permissions
4. Ensure JSONL file format is correct

## 📚 **Documentation**

- **`FULL_IMPORT_GUIDE.md`** - Detailed import instructions
- **Database Schema** - See `../migrations/` for table structure
- **Environment Setup** - See `../.env.example` for configuration

---

**Last Updated:** October 2024  
**Version:** 2.0  
**Status:** Production Ready ✅