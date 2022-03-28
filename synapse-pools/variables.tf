variable "postfix" {
  type        = string
  default     = "001"
  description = "Postfix for the module name"
}

variable "synapse_workspace_id" {
  type        = string
  description = "The ID of the Synapse workspace"
}

variable "enable_syn_sqlpool" {
  description = "Variable to enable or disable Synapse Dedicated SQL pool deployment"
  default     = false
}

variable "enable_syn_sparkpool" {
  description = "Variable to enable or disable Synapse Spark pool deployment"
  default     = false
}
