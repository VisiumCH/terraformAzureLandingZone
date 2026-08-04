variable "application_name" {
    type = string
}

variable "primary_location" {
    type = string
}

variable "containers" {
    type = map(object({
        name = string
    }))
}

variable "tenant_id" {
    type = string
}

# variable "storage_account_state" {
#     type = string
# }

# variable "container_state" {
#     type = string
# }

# variable "key_state" {
#     type = string
# }