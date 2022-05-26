OUTPUT_DIR="/state/partition1/node_controller/output"
STORAGE_DIR="/storage/frbid_cands"

# Print out error message if we have more than 5% of candidates
# not processed correctly. Print out an error otherwise
ERROR_THRESHOLD=0.05
# The amount of disk space we are not willing to go below
# Ask what to do if we were to reach that limit by downloading
# the candidates.
STORAGE_LIMIT_GIB=200
STORAGE_LIMIT_MIB=$((STORAGE_LIMIT_GIB * 1024))
