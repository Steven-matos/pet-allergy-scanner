#!/bin/bash
# Script to update all Pydantic models to V2 syntax

echo "🔧 Updating Pydantic models to V2 syntax..."

# Add ConfigDict to imports in all model files
find app/models -name "*.py" -type f -exec sed -i '' 's/from pydantic import \(.*\)BaseModel\(.*\)/from pydantic import \1BaseModel, ConfigDict\2/g' {} \;

# Replace Config class patterns
find app/models -name "*.py" -type f -exec perl -i -pe '
    s/class Config:\s*\n\s*from_attributes = True\s*\n\s*allow_population_by_field_name = True/model_config = ConfigDict(from_attributes=True, populate_by_name=True)/g;
    s/class Config:\s*\n\s*allow_population_by_field_name = True/model_config = ConfigDict(populate_by_name=True)/g;
    s/class Config:\s*\n\s*validate_by_name = True/model_config = ConfigDict(populate_by_name=True)/g;
    s/class Config:\s*\n\s*from_attributes = True\s*\n\s*validate_by_name = True/model_config = ConfigDict(from_attributes=True, populate_by_name=True)/g;
    s/class Config:\s*\n\s*from_attributes = True/model_config = ConfigDict(from_attributes=True)/g;
' {} \;

echo "✅ Pydantic V2 updates complete!"
echo "🧪 Testing imports..."

cd /Users/stevenmatos/Code/pet-allergy-scanner/server
python3 -c "from app.models import *; print('✅ All models load successfully')" 2>&1

echo "Done!"

