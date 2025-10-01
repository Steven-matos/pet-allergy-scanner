# Terminology Change: Allergies → Sensitivities

## Overview
Changed terminology from "allergies" to "sensitivities" (food sensitivities) throughout the entire codebase to better reflect the actual use case.

## Changes Made

### iOS/Swift (Frontend)

#### Models
- **Pet.swift**: 
  - `knownAllergies` → `knownSensitivities`
  - Updated `CodingKeys` to use `"known_sensitivities"`
  - Updated PetCreate and PetUpdate models

#### Views
- **PetsView.swift**:
  - Updated card labels: "Allergies" → "Sensitivities"
  - Updated section header: "Known Allergies" → "Food Sensitivities"
  - Updated variable names and references

- **AddPetView.swift**:
  - `knownAllergies` → `knownSensitivities`
  - `newAllergy` → `newSensitivity`
  - Updated section: "Known Allergies" → "Food Sensitivities"
  - Updated placeholder: "Add allergy" → "Add sensitivity"

- **EditPetView.swift**:
  - Same changes as AddPetView.swift
  - Updated all form references

- **OnboardingView.swift**:
  - `knownAllergies` → `knownSensitivities`
  - `newAllergy` → `newSensitivity`
  - Updated section: "Known Allergies (Optional)" → "Food Sensitivities (Optional)"

- **MockData.swift**:
  - Updated all mock pet data to use `knownSensitivities`

### Python (Backend)

#### Models
- **app/models/pet.py**:
  - `known_allergies` → `known_sensitivities` in PetBase
  - Updated PetUpdate model
  - Updated all docstrings

#### Routers
- **app/routers/pets.py**:
  - Updated all database field references
  - Changed `known_allergies` to `known_sensitivities` in insert/update operations

- **app/routers/scans.py**:
  - `pet_allergies` → `pet_sensitivities` parameter

- **app/routers/ingredients.py**:
  - Function parameter: `pet_allergies` → `pet_sensitivities`
  - Updated function body and logic
  - Updated docstring: "known allergies" → "known sensitivities"
  - Updated reason message: "Known allergen for this pet" → "Known food sensitivity for this pet"

### Database

#### Schema
- **database_schemas/database_schema.sql**:
  - Column: `known_allergies` → `known_sensitivities`

#### Migration
- **migrations/rename_allergies_to_sensitivities.sql**:
  - New migration script to rename the column in existing databases
  - Includes column comment update

## Migration Steps

To apply these changes to an existing database:

```sql
-- Run the migration script
psql -d your_database < server/migrations/rename_allergies_to_sensitivities.sql
```

Or execute directly:
```sql
ALTER TABLE pets RENAME COLUMN known_allergies TO known_sensitivities;
COMMENT ON COLUMN pets.known_sensitivities IS 'List of known food sensitivities for the pet';
```

## API Changes

### Request/Response Format
All API endpoints now use `known_sensitivities` instead of `known_allergies`:

**Before:**
```json
{
  "name": "Max",
  "species": "dog",
  "known_allergies": ["chicken", "wheat"]
}
```

**After:**
```json
{
  "name": "Max",
  "species": "dog",
  "known_sensitivities": ["chicken", "wheat"]
}
```

## Testing Checklist

- [ ] iOS app compiles without errors
- [ ] Backend server starts without errors
- [ ] Database migration runs successfully
- [ ] Create pet with sensitivities works
- [ ] Update pet sensitivities works
- [ ] Pet list displays sensitivities correctly
- [ ] Pet detail card shows "Food Sensitivities"
- [ ] Scan analysis uses sensitivities correctly
- [ ] All API endpoints return correct field names

## Notes

- This is a **breaking change** for existing API clients
- All existing data will be preserved during migration
- The meaning/functionality remains the same, only the terminology changed
- UI now consistently refers to "Food Sensitivities" or just "Sensitivities"

