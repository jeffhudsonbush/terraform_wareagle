terraform {
  required_version = ">= 1.5.0"

  required_providers {
    pagerduty = {
      source  = "PagerDuty/pagerduty"
      version = "3.34.0"
    }
  }
}

###############################################################################
# VARIABLES
###############################################################################

variable "pagerduty_token" {
  description = "PagerDuty API token"
  type        = string
  sensitive   = true
}

variable "time_zone" {
  description = "Timezone for the Austin schedules"
  type        = string
  default     = "America/Chicago"
}

###############################################################################
# PROVIDER
###############################################################################

provider "pagerduty" {
  token = var.pagerduty_token
}

###############################################################################
# TEAM
###############################################################################

resource "pagerduty_team" "austin_longhorns" {
  name        = "Austin Longhorns"
  description = "Demo PagerDuty team for the Austin Longhorns Match service"
}

###############################################################################
# DEMO USERS
###############################################################################

resource "pagerduty_user" "demo" {
  for_each = {
    austin_1 = {
      name  = "Austin Longhorns Demo 1"
      email = "austin.longhorns.demo1@example.com"
    }

    austin_2 = {
      name  = "Austin Longhorns Demo 2"
      email = "austin.longhorns.demo2@example.com"
    }

    austin_3 = {
      name  = "Austin Longhorns Demo 3"
      email = "austin.longhorns.demo3@example.com"
    }

    austin_4 = {
      name  = "Austin Longhorns Demo 4"
      email = "austin.longhorns.demo4@example.com"
    }

    austin_5 = {
      name  = "Austin Longhorns Demo 5"
      email = "austin.longhorns.demo5@example.com"
    }
  }

  name  = each.value.name
  email = each.value.email

  teams = [
    pagerduty_team.austin_longhorns.id
  ]
}

###############################################################################
# PRIMARY SCHEDULE
#
# Default rotation:
# - 5 users
# - 1 user on call at a time
# - 1-week rotation
###############################################################################

resource "pagerduty_schedule" "austin_primary" {
  name        = "Austin Primary"
  description = "Primary on-call rotation for Austin Longhorns"
  time_zone   = var.time_zone

  teams = [
    pagerduty_team.austin_longhorns.id
  ]

  layer {
    name                         = "Default Rotation"
    start                        = "2026-08-17T00:00:00-05:00"
    rotation_virtual_start       = "2026-08-17T00:00:00-05:00"
    rotation_turn_length_seconds = 604800

    users = [
      pagerduty_user.demo["austin_1"].id,
      pagerduty_user.demo["austin_2"].id,
      pagerduty_user.demo["austin_3"].id,
      pagerduty_user.demo["austin_4"].id,
      pagerduty_user.demo["austin_5"].id
    ]
  }
}

###############################################################################
# SECONDARY SCHEDULE
#
# Default rotation:
# - Same 5 demo users
# - 1 user on call at a time
# - 1-week rotation
#
# Offset by one user so Primary and Secondary do not start with the same
# person.
###############################################################################

resource "pagerduty_schedule" "austin_secondary" {
  name        = "Austin Secondary"
  description = "Secondary on-call rotation for Austin Longhorns"
  time_zone   = var.time_zone

  teams = [
    pagerduty_team.austin_longhorns.id
  ]

  layer {
    name                         = "Default Rotation"
    start                        = "2026-08-17T00:00:00-05:00"
    rotation_virtual_start       = "2026-08-17T00:00:00-05:00"
    rotation_turn_length_seconds = 604800

    users = [
      pagerduty_user.demo["austin_3"].id,
      pagerduty_user.demo["austin_4"].id,
      pagerduty_user.demo["austin_5"].id,
      pagerduty_user.demo["austin_1"].id,
      pagerduty_user.demo["austin_2"].id
    ]
  }
}

###############################################################################
# ESCALATION POLICY
#
# York:
#   Level 1 -> Austin Primary
#   Level 2 -> Austin Secondary
###############################################################################

resource "pagerduty_escalation_policy" "york" {
  name        = "York"
  description = "York escalation policy for the Match service"
  num_loops   = 2

  teams = [
    pagerduty_team.austin_longhorns.id
  ]

  rule {
    escalation_delay_in_minutes = 15

    target {
      type = "schedule_reference"
      id   = pagerduty_schedule.austin_primary.id
    }
  }

  rule {
    escalation_delay_in_minutes = 15

    target {
      type = "schedule_reference"
      id   = pagerduty_schedule.austin_secondary.id
    }
  }
}

###############################################################################
# MATCH SERVICE
###############################################################################

resource "pagerduty_service" "match" {
  name                    = "Match"
  description             = "Match service for Austin Longhorns"
  auto_resolve_timeout    = 14400
  acknowledgement_timeout = 600

  escalation_policy = pagerduty_escalation_policy.york.id

  alert_creation = "create_alerts_and_incidents"
}

###############################################################################
# OUTPUTS
###############################################################################

output "team_id" {
  description = "Austin Longhorns PagerDuty team ID"
  value       = pagerduty_team.austin_longhorns.id
}

output "demo_user_ids" {
  description = "PagerDuty IDs for the five demo users"
  value = {
    for key, user in pagerduty_user.demo :
    key => user.id
  }
}

output "primary_schedule_id" {
  description = "Austin Primary schedule ID"
  value       = pagerduty_schedule.austin_primary.id
}

output "secondary_schedule_id" {
  description = "Austin Secondary schedule ID"
  value       = pagerduty_schedule.austin_secondary.id
}

output "escalation_policy_id" {
  description = "York escalation policy ID"
  value       = pagerduty_escalation_policy.york.id
}

output "match_service_id" {
  description = "Match service ID"
  value       = pagerduty_service.match.id
}