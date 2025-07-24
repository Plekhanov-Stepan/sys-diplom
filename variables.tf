variable "cloud_id" {
  type    = string
  default = "b1gcsckd9icfm5aq020p"
}
variable "folder_id" {
  type    = string
  default = "b1g25aqtihsjrqvi6v5p"
}

variable "test" {
  type = map(number)
  default = {
    cores         = 2
    memory        = 1
    core_fraction = 20
  }
}

