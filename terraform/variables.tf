variable "n" {
  description = "name"
  type        = string
}

variable "r" {
  description = "region"
  type        = string
  default     = "us-east-1"
}

variable "img" {
  description = "container image"
  type        = string
}

variable "p" {
  description = "port"
  type        = number
  default     = 8080
}

variable "cnt" {
  description = "count"
  type        = number
  default     = 2
}

variable "cpu_val" {
  description = "cpu"
  type        = string
  default     = "512"
}

variable "mem" {
  description = "memory"
  type        = string
  default     = "1024"
}

variable "mn" {
  description = "min capacity"
  type        = number
  default     = 1
}

variable "mx" {
  description = "max capacity"
  type        = number
  default     = 10
}

variable "vpc" {
  description = "vpc id"
  type        = string
}

variable "sn" {
  description = "subnets"
  type        = list(string)
}

variable "e" {
  description = "environment"
  type        = string
  default     = "prod"
}

variable "tgt" {
  description = "threshold for scaling"
  type        = number
  default     = 75
}

variable "localstack_endpoint" {
  description = "localstack endpoint url"
  type        = string
  default     = "http://localhost:4566"
}
