# Random suffix for resource names
resource "random_id" "stack_suffix" {
  byte_length = 4

  # Keepers ensure the random_id is stable and only changes if these values change
  keepers = {
    stack_name = var.stack_name
  }
}
