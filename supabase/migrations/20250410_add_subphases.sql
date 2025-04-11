-- Script de migration pour l'ajout des sous-phases
-- Date: 2025-04-10

-- Add parent_phase_id column to phases table
ALTER TABLE "public"."phases" 
  ADD COLUMN "parent_phase_id" UUID REFERENCES "public"."phases"("id") ON DELETE CASCADE;

-- Add comment to column
COMMENT ON COLUMN "public"."phases"."parent_phase_id" IS 'ID of the parent phase, null for main phases';

-- Create index on parent_phase_id for better performance
CREATE INDEX "idx_phases_parent_phase_id" ON "public"."phases" ("parent_phase_id");

-- Add sub_phase_id column to tasks table
ALTER TABLE "public"."tasks" 
  ADD COLUMN "sub_phase_id" UUID REFERENCES "public"."phases"("id") ON DELETE SET NULL;

-- Add comment to column
COMMENT ON COLUMN "public"."tasks"."sub_phase_id" IS 'ID of the sub-phase, null if the task is directly associated with a main phase';

-- Create index on sub_phase_id for better performance
CREATE INDEX "idx_tasks_sub_phase_id" ON "public"."tasks" ("sub_phase_id");

-- Au lieu d'une contrainte CHECK avec sous-requête (non supportée), utiliser un trigger

-- Créer une fonction pour le trigger qui vérifie que sub_phase_id appartient à phase_id
CREATE OR REPLACE FUNCTION check_sub_phase_belongs_to_phase()
RETURNS TRIGGER AS $$
BEGIN
    -- Si sub_phase_id est NULL, c'est valide
    IF NEW.sub_phase_id IS NULL THEN
        RETURN NEW;
    END IF;
    
    -- Vérifier que la sous-phase est bien une sous-phase de la phase principale
    IF NOT EXISTS (
        SELECT 1 FROM phases 
        WHERE id = NEW.sub_phase_id AND parent_phase_id = NEW.phase_id
    ) THEN
        RAISE EXCEPTION 'La sous-phase doit appartenir à la phase principale';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Créer le trigger pour vérifier l'intégrité à chaque insertion ou mise à jour
CREATE TRIGGER check_sub_phase_relation
BEFORE INSERT OR UPDATE ON "public"."tasks"
FOR EACH ROW
EXECUTE FUNCTION check_sub_phase_belongs_to_phase();

-- Mettre à jour les politiques RLS pour les sous-phases

-- Mise à jour des politiques de sécurité pour prendre en compte les sous-phases
DO $$
BEGIN
  -- Vérifier que la politique existe avant de la modifier
  IF EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'phases'
      AND policyname = 'User can see phases they have access to'
  ) THEN
    -- Mettre à jour la politique pour les phases
    ALTER POLICY "User can see phases they have access to" 
    ON "public"."phases" 
    USING (
      auth.uid() IN (
        SELECT team_users.user_id
        FROM teams
        JOIN team_users ON teams.id = team_users.team_id
        WHERE teams.id = (
          SELECT team_id
          FROM projects
          WHERE projects.id = phases.project_id
        )
      )
    );
  END IF;
END $$;
