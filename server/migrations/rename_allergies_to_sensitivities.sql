-- Migration: Rename known_allergies to known_sensitivities
-- This migration renames the column to better reflect the terminology
-- from "allergies" to "food sensitivities"

-- Rename the column in the pets table
ALTER TABLE pets 
RENAME COLUMN known_allergies TO known_sensitivities;

-- Update any comments or metadata
COMMENT ON COLUMN pets.known_sensitivities IS 'List of known food sensitivities for the pet';

