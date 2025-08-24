# Sleeper API Analysis Report

Generated: 2025-08-24T01:07:38.836364
League ID: 1199102384316362752

## Executive Summary

This document contains a comprehensive analysis of the Sleeper API endpoints, their response structures, 
data relationships, and performance characteristics.

## Rate Limit Analysis

{
  "total_calls": 18,
  "successful_calls": 18,
  "failed_calls": 0,
  "rate_limit_errors": 0,
  "avg_response_time": 0.10685345861646864,
  "max_response_time": 0.42412590980529785,
  "min_response_time": -1.3802616596221924,
  "calls_per_second": 9.358611438019249
}

**Key Findings:**
- No explicit rate limiting detected (no 429 responses)
- Average response time: 0.107s
- All endpoints responded successfully
- API appears to have generous or no rate limits

## Endpoint Analysis

### League

**Data Structure:**
```json
{
  "type": "object",
  "properties": {
    "name": {
      "type": "string",
      "example": "De Pere Legends"
    },
    "status": {
      "type": "string",
      "example": "in_season"
    },
    "metadata": {
      "type": "object",
      "properties": {
        "auto_continue": {
          "type": "string",
          "example": "on"
        },
        "keeper_deadline": {
          "type": "string",
          "example": "0"
        },
        "latest_league_winner_roster_id": {
          "type": "string",
          "example": "4"
        }
      }
    },
    "settings": {
      "type": "object",
      "properties": {
        "best_ball": {
          "type": "number",
          "example": 0
        },
        "waiver_budget": {
          "type": "number",
          "example": 100
        },
        "disable_adds": {
          "type": "number",
          "example": 0
        },
        "capacity_override": {
          "type": "number",
          "example": 0
        },
        "waiver_bid_min": {
          "type": "number",
          "example": 0
        },
        "taxi_deadline": {
          "type": "number",
          "example": 4
        },
        "draft_rounds": {
          "type": "number",
          "example": 3
        },
        "reserve_allow_na": {
          "type": "number",
          "example": 1
        },
        "start_week": {
          "type": "number",
          "example": 1
        },
        "playoff_seed_type": {
          "type": "number",
          "example": 0
        },
        "playoff_teams": {
          "type": "number",
          "example": 6
        },
        "veto_votes_needed": {
          "type": "number",
          "example": 6
        },
        "num_teams": {
          "type": "number",
          "example": 12
        },
        "daily_waivers_hour": {
          "type": "number",
          "example": 10
        },
        "playoff_type": {
          "type": "number",
          "example": 0
        },
        "taxi_slots": {
          "type": "number",
          "example": 3
        },
        "sub_start_time_eligibility": {
          "type": "number",
          "example": 0
        },
        "daily_waivers_days": {
          "type": "number",
          "example": 10921
        },
        "sub_lock_if_starter_active": {
          "type": "number",
          "example": 0
        },
        "playoff_week_start": {
          "type": "number",
          "example": 15
        },
        "...": {
          "note": "and 29 more properties"
        }
      }
    },
    "avatar": {
      "type": "string",
      "example": "8aaa5bdb4e52a06943281a7007ca5e3a"
    },
    "company_id": {
      "type": "null"
    },
    "shard": {
      "type": "number",
      "example": 294
    },
    "season": {
      "type": "string",
      "example": "2025"
    },
    "season_type": {
      "type": "string",
      "example": "regular"
    },
    "sport": {
      "type": "string",
      "example": "nfl"
    },
    "last_message_id": {
      "type": "string",
      "example": "1265192771958870016"
    },
    "scoring_settings": {
      "type": "object",
      "properties": {
        "sack": {
          "type": "number",
          "example": 0.0
        },
        "qb_hit": {
          "type": "number",
          "example": 0.0
        },
        "fgm_40_49": {
          "type": "number",
          "example": 0.0
        },
        "fgm_yds": {
          "type": "number",
          "example": 0.0
        },
        "def_forced_punts": {
          "type": "number",
          "example": 0.0
        },
        "pass_int": {
          "type": "number",
          "example": -1.0
        },
        "fgmiss_50p": {
          "type": "number",
          "example": 0.0
        },
        "pts_allow_0": {
          "type": "number",
          "example": 0.0
        },
        "pass_2pt": {
          "type": "number",
          "example": 2.0
        },
        "yds_allow_450_499": {
          "type": "number",
          "example": 0.0
        },
        "st_td": {
          "type": "number",
          "example": 6.0
        },
        "sack_yd": {
          "type": "number",
          "example": 0.0
        },
        "fgm_yds_over_30": {
          "type": "number",
          "example": 0.0
        },
        "rec_td": {
          "type": "number",
          "example": 6.0
        },
        "yds_allow_400_449": {
          "type": "number",
          "example": 0.0
        },
        "tkl_ast": {
          "type": "number",
          "example": 0.0
        },
        "fgm_30_39": {
          "type": "number",
          "example": 0.0
        },
        "xpmiss": {
          "type": "number",
          "example": 0.0
        },
        "rush_td": {
          "type": "number",
          "example": 6.0
        },
        "pts_allow": {
          "type": "number",
          "example": 0.0
        },
        "...": {
          "note": "and 58 more properties"
        }
      }
    },
    "last_author_avatar": {
      "type": "string",
      "example": "5cc45bfa746186eb476a703dc6a612e5"
    },
    "last_author_display_name": {
      "type": "string",
      "example": "gizmoduck5"
    },
    "last_author_id": {
      "type": "string",
      "example": "831639450038665216"
    },
    "last_author_is_bot": {
      "type": "number",
      "example": false
    },
    "last_message_attachment": {
      "type": "null"
    },
    "last_message_text_map": {
      "type": "null"
    },
    "last_message_time": {
      "type": "number",
      "example": 1756007972285
    },
    "last_pinned_message_id": {
      "type": "string",
      "example": "1219403386256896000"
    },
    "...": {
      "note": "and 11 more properties"
    }
  }
}
```


### Users

**Data Structure:**
```json
{
  "type": "array",
  "count": 12,
  "items": {
    "type": "object",
    "properties": {
      "avatar": {
        "type": "string",
        "example": "a7edf17a1956ebe79017732156625301"
      },
      "display_name": {
        "type": "string",
        "example": "rab12345"
      },
      "is_bot": {
        "type": "number",
        "example": false
      },
      "is_owner": {
        "type": "number",
        "example": false
      },
      "league_id": {
        "type": "string",
        "example": "1199102384316362752"
      },
      "metadata": {
        "type": "object",
        "properties": {
          "allow_pn": {
            "type": "str",
            "truncated": true
          },
          "allow_sms": {
            "type": "str",
            "truncated": true
          },
          "avatar": {
            "type": "str",
            "truncated": true
          },
          "mention_pn": {
            "type": "str",
            "truncated": true
          },
          "team_name": {
            "type": "str",
            "truncated": true
          }
        }
      },
      "settings": {
        "type": "null"
      },
      "user_id": {
        "type": "string",
        "example": "213866320939196416"
      }
    }
  }
}
```

**Record Count:** 12


### Rosters

**Data Structure:**
```json
{
  "type": "array",
  "count": 12,
  "items": {
    "type": "object",
    "properties": {
      "co_owners": {
        "type": "null"
      },
      "keepers": {
        "type": "null"
      },
      "league_id": {
        "type": "string",
        "example": "1199102384316362752"
      },
      "metadata": {
        "type": "null"
      },
      "owner_id": {
        "type": "string",
        "example": "831639450038665216"
      },
      "player_map": {
        "type": "null"
      },
      "players": {
        "type": "array",
        "count": 20,
        "items": {
          "type": "str",
          "truncated": true
        }
      },
      "reserve": {
        "type": "null"
      },
      "roster_id": {
        "type": "number",
        "example": 1
      },
      "settings": {
        "type": "object",
        "properties": {
          "fpts": {
            "type": "int",
            "truncated": true
          },
          "losses": {
            "type": "int",
            "truncated": true
          },
          "ties": {
            "type": "int",
            "truncated": true
          },
          "total_moves": {
            "type": "int",
            "truncated": true
          },
          "waiver_budget_used": {
            "type": "int",
            "truncated": true
          },
          "waiver_position": {
            "type": "int",
            "truncated": true
          },
          "wins": {
            "type": "int",
            "truncated": true
          }
        }
      },
      "starters": {
        "type": "array",
        "count": 8,
        "items": {
          "type": "str",
          "truncated": true
        }
      },
      "taxi": {
        "type": "array",
        "count": 3,
        "items": {
          "type": "str",
          "truncated": true
        }
      }
    }
  }
}
```

**Analysis:**
{
  "total_rosters": 12,
  "players_per_roster": [
    20,
    25,
    27,
    24,
    24,
    23,
    26,
    27,
    24,
    24,
    22,
    23
  ],
  "starters_per_roster": [
    8,
    8,
    8,
    8,
    8,
    8,
    8,
    8,
    8,
    8,
    8,
    8
  ],
  "has_co_owners": false
}

**Record Count:** 12


### Matchups


### Transactions


### Winners Bracket

**Data Structure:**
```json
{
  "type": "array",
  "count": 7,
  "items": {
    "type": "object",
    "properties": {
      "m": {
        "type": "number",
        "example": 1
      },
      "r": {
        "type": "number",
        "example": 1
      },
      "l": {
        "type": "null"
      },
      "w": {
        "type": "null"
      },
      "t1": {
        "type": "number",
        "example": 9
      },
      "t2": {
        "type": "number",
        "example": 8
      }
    }
  }
}
```


### Losers Bracket

**Data Structure:**
```json
{
  "type": "array",
  "count": 7,
  "items": {
    "type": "object",
    "properties": {
      "m": {
        "type": "number",
        "example": 1
      },
      "r": {
        "type": "number",
        "example": 1
      },
      "l": {
        "type": "null"
      },
      "w": {
        "type": "null"
      },
      "t1": {
        "type": "number",
        "example": 3
      },
      "t2": {
        "type": "number",
        "example": 2
      }
    }
  }
}
```


### Traded Picks

**Data Structure:**
```json
{
  "type": "array",
  "count": 10,
  "items": {
    "type": "object",
    "properties": {
      "round": {
        "type": "number",
        "example": 1
      },
      "season": {
        "type": "string",
        "example": "2025"
      },
      "roster_id": {
        "type": "number",
        "example": 1
      },
      "owner_id": {
        "type": "number",
        "example": 8
      },
      "previous_owner_id": {
        "type": "number",
        "example": 1
      }
    }
  }
}
```

**Record Count:** 10


### User Detail

**Data Structure:**
```json
{
  "type": "object",
  "properties": {
    "avatar": {
      "type": "string",
      "example": "a7edf17a1956ebe79017732156625301"
    },
    "cookies": {
      "type": "null"
    },
    "created": {
      "type": "null"
    },
    "currencies": {
      "type": "null"
    },
    "data_updated": {
      "type": "null"
    },
    "deleted": {
      "type": "null"
    },
    "display_name": {
      "type": "string",
      "example": "rab12345"
    },
    "email": {
      "type": "null"
    },
    "is_bot": {
      "type": "number",
      "example": false
    },
    "metadata": {
      "type": "null"
    },
    "notifications": {
      "type": "null"
    },
    "pending": {
      "type": "null"
    },
    "phone": {
      "type": "null"
    },
    "real_name": {
      "type": "null"
    },
    "solicitable": {
      "type": "null"
    },
    "summoner_name": {
      "type": "null"
    },
    "summoner_region": {
      "type": "null"
    },
    "token": {
      "type": "null"
    },
    "user_id": {
      "type": "string",
      "example": "213866320939196416"
    },
    "username": {
      "type": "string",
      "example": "rab12345"
    },
    "...": {
      "note": "and 1 more properties"
    }
  }
}
```


### User Leagues

**Data Structure:**
```json
{
  "type": "array",
  "count": 1,
  "items": {
    "type": "object",
    "properties": {
      "company_id": {
        "type": "null"
      },
      "bracket_id": {
        "type": "null"
      },
      "avatar": {
        "type": "string",
        "example": "8aaa5bdb4e52a06943281a7007ca5e3a"
      },
      "roster_positions": {
        "type": "array",
        "count": 26,
        "items": {
          "type": "str",
          "truncated": true
        }
      },
      "season_type": {
        "type": "string",
        "example": "regular"
      },
      "shard": {
        "type": "number",
        "example": 294
      },
      "group_id": {
        "type": "null"
      },
      "last_pinned_message_id": {
        "type": "string",
        "example": "1219403386256896000"
      },
      "last_author_display_name": {
        "type": "string",
        "example": "gizmoduck5"
      },
      "last_author_is_bot": {
        "type": "number",
        "example": false
      },
      "loser_bracket_overrides_id": {
        "type": "null"
      },
      "status": {
        "type": "string",
        "example": "in_season"
      },
      "bracket_overrides_id": {
        "type": "null"
      },
      "metadata": {
        "type": "object",
        "properties": {
          "auto_continue": {
            "type": "str",
            "truncated": true
          },
          "keeper_deadline": {
            "type": "str",
            "truncated": true
          },
          "latest_league_winner_roster_id": {
            "type": "str",
            "truncated": true
          }
        }
      },
      "name": {
        "type": "string",
        "example": "De Pere Legends"
      },
      "last_transaction_id": {
        "type": "number",
        "example": 1264809996873383936
      },
      "last_message_attachment": {
        "type": "null"
      },
      "sport": {
        "type": "string",
        "example": "nfl"
      },
      "last_message_id": {
        "type": "string",
        "example": "1265192771958870016"
      },
      "display_order": {
        "type": "number",
        "example": 0
      },
      "...": {
        "note": "and 13 more properties"
      }
    }
  }
}
```

**Record Count:** 1


### Draft Detail

**Data Structure:**
```json
{
  "type": "object",
  "properties": {
    "created": {
      "type": "number",
      "example": 1740250795972
    },
    "creators": {
      "type": "array",
      "count": 1,
      "items": {
        "type": "string",
        "example": "831639450038665216"
      }
    },
    "draft_id": {
      "type": "string",
      "example": "1199102384333144064"
    },
    "draft_order": {
      "type": "object",
      "properties": {
        "1002538112812814336": {
          "type": "number",
          "example": 8
        },
        "1116038984116846592": {
          "type": "number",
          "example": 5
        },
        "1116150314396147712": {
          "type": "number",
          "example": 9
        },
        "1122157980096626688": {
          "type": "number",
          "example": 11
        },
        "1126345201179566080": {
          "type": "number",
          "example": 7
        },
        "1127802870893600768": {
          "type": "number",
          "example": 6
        },
        "213866320939196416": {
          "type": "number",
          "example": 10
        },
        "484790555675455488": {
          "type": "number",
          "example": 2
        },
        "819426386337984512": {
          "type": "number",
          "example": 3
        },
        "831639450038665216": {
          "type": "number",
          "example": 4
        },
        "873281472038146048": {
          "type": "number",
          "example": 1
        },
        "995173024489861120": {
          "type": "number",
          "example": 12
        }
      }
    },
    "last_message_id": {
      "type": "string",
      "example": "1252483106074537984"
    },
    "last_message_time": {
      "type": "number",
      "example": 1752977751801
    },
    "last_picked": {
      "type": "number",
      "example": 1752977751213
    },
    "league_id": {
      "type": "string",
      "example": "1199102384316362752"
    },
    "metadata": {
      "type": "object",
      "properties": {
        "description": {
          "type": "string",
          "example": ""
        },
        "name": {
          "type": "string",
          "example": "De Pere Legends"
        },
        "scoring_type": {
          "type": "string",
          "example": "dynasty_ppr"
        }
      }
    },
    "season": {
      "type": "string",
      "example": "2025"
    },
    "season_type": {
      "type": "string",
      "example": "regular"
    },
    "settings": {
      "type": "object",
      "properties": {
        "alpha_sort": {
          "type": "number",
          "example": 0
        },
        "autopause_enabled": {
          "type": "number",
          "example": 0
        },
        "autopause_end_time": {
          "type": "number",
          "example": 900
        },
        "autopause_start_time": {
          "type": "number",
          "example": 180
        },
        "autostart": {
          "type": "number",
          "example": 0
        },
        "cpu_autopick": {
          "type": "number",
          "example": 1
        },
        "enforce_position_limits": {
          "type": "number",
          "example": 1
        },
        "nomination_timer": {
          "type": "number",
          "example": 60
        },
        "pick_timer": {
          "type": "number",
          "example": 3600
        },
        "player_type": {
          "type": "number",
          "example": 1
        },
        "reversal_round": {
          "type": "number",
          "example": 0
        },
        "rounds": {
          "type": "number",
          "example": 3
        },
        "slots_bn": {
          "type": "number",
          "example": 18
        },
        "slots_flex": {
          "type": "number",
          "example": 2
        },
        "slots_qb": {
          "type": "number",
          "example": 1
        },
        "slots_rb": {
          "type": "number",
          "example": 2
        },
        "slots_te": {
          "type": "number",
          "example": 1
        },
        "slots_wr": {
          "type": "number",
          "example": 2
        },
        "teams": {
          "type": "number",
          "example": 12
        }
      }
    },
    "slot_to_roster_id": {
      "type": "object",
      "properties": {
        "1": {
          "type": "number",
          "example": 12
        },
        "10": {
          "type": "number",
          "example": 7
        },
        "11": {
          "type": "number",
          "example": 5
        },
        "12": {
          "type": "number",
          "example": 4
        },
        "2": {
          "type": "number",
          "example": 11
        },
        "3": {
          "type": "number",
          "example": 8
        },
        "4": {
          "type": "number",
          "example": 1
        },
        "5": {
          "type": "number",
          "example": 2
        },
        "6": {
          "type": "number",
          "example": 10
        },
        "7": {
          "type": "number",
          "example": 9
        },
        "8": {
          "type": "number",
          "example": 6
        },
        "9": {
          "type": "number",
          "example": 3
        }
      }
    },
    "sport": {
      "type": "string",
      "example": "nfl"
    },
    "start_time": {
      "type": "number",
      "example": 1752944578371
    },
    "status": {
      "type": "string",
      "example": "complete"
    },
    "type": {
      "type": "string",
      "example": "linear"
    }
  }
}
```


### Draft Picks

**Data Structure:**
```json
{
  "type": "array",
  "count": 36,
  "items": {
    "type": "object",
    "properties": {
      "draft_id": {
        "type": "string",
        "example": "1199102384333144064"
      },
      "draft_slot": {
        "type": "number",
        "example": 1
      },
      "is_keeper": {
        "type": "null"
      },
      "metadata": {
        "type": "object",
        "properties": {
          "first_name": {
            "type": "str",
            "truncated": true
          },
          "injury_status": {
            "type": "str",
            "truncated": true
          },
          "last_name": {
            "type": "str",
            "truncated": true
          },
          "news_updated": {
            "type": "str",
            "truncated": true
          },
          "number": {
            "type": "str",
            "truncated": true
          },
          "player_id": {
            "type": "str",
            "truncated": true
          },
          "position": {
            "type": "str",
            "truncated": true
          },
          "sport": {
            "type": "str",
            "truncated": true
          },
          "status": {
            "type": "str",
            "truncated": true
          },
          "team": {
            "type": "str",
            "truncated": true
          },
          "team_abbr": {
            "type": "str",
            "truncated": true
          },
          "team_changed_at": {
            "type": "str",
            "truncated": true
          },
          "years_exp": {
            "type": "str",
            "truncated": true
          }
        }
      },
      "pick_no": {
        "type": "number",
        "example": 1
      },
      "picked_by": {
        "type": "string",
        "example": "873281472038146048"
      },
      "player_id": {
        "type": "string",
        "example": "12527"
      },
      "reactions": {
        "type": "null"
      },
      "roster_id": {
        "type": "number",
        "example": 12
      },
      "round": {
        "type": "number",
        "example": 1
      }
    }
  }
}
```


### Trending Players

**Data Structure:**
```json
{
  "type": "array",
  "count": 25,
  "items": {
    "type": "object",
    "properties": {
      "count": {
        "type": "number",
        "example": 123138
      },
      "player_id": {
        "type": "string",
        "example": "10219"
      }
    }
  }
}
```

**Record Count:** 25


### Nfl State

**Data Structure:**
```json
{
  "type": "object",
  "properties": {
    "week": {
      "type": "number",
      "example": 1
    },
    "leg": {
      "type": "number",
      "example": 1
    },
    "season": {
      "type": "string",
      "example": "2025"
    },
    "season_type": {
      "type": "string",
      "example": "regular"
    },
    "league_season": {
      "type": "string",
      "example": "2025"
    },
    "previous_season": {
      "type": "string",
      "example": "2024"
    },
    "season_start_date": {
      "type": "string",
      "example": "2025-09-04"
    },
    "display_week": {
      "type": "number",
      "example": 1
    },
    "league_create_season": {
      "type": "string",
      "example": "2025"
    },
    "season_has_scores": {
      "type": "number",
      "example": true
    }
  }
}
```


## Data Relationships

### Primary Keys and Foreign Keys

1. **League**
   - Primary Key: `league_id`
   - Foreign Keys: `draft_id`, `previous_league_id`

2. **User**
   - Primary Key: `user_id`
   - Relationships: Many-to-Many with Leagues through Rosters

3. **Roster**
   - Primary Key: Composite (`league_id`, `roster_id`)
   - Foreign Keys: `owner_id` (user), `league_id`, `co_owners[]` (users)

4. **Matchup**
   - Primary Key: Composite (`league_id`, `week`, `roster_id`)
   - Foreign Keys: `roster_id`, uses `matchup_id` for pairing

5. **Transaction**
   - Primary Key: `transaction_id`
   - Foreign Keys: `creator` (user), `roster_ids[]`, `league_id`

6. **Draft**
   - Primary Key: `draft_id`
   - Relationships: One-to-One with League

### Data Flow

```
League
  ├── Users (through rosters)
  ├── Rosters
  │   ├── Players (array of player_ids)
  │   └── Starters (subset of players)
  ├── Matchups (by week)
  │   └── Player Points (nested in matchup)
  ├── Transactions (by week)
  │   ├── Adds (players added)
  │   └── Drops (players dropped)
  └── Draft
      └── Picks (ordered list)
```

## Key Observations

1. **No Pagination**: All endpoints return complete datasets
2. **Weekly Data**: Matchups and transactions are organized by week
3. **Nested Data**: Heavy use of nested objects and arrays
4. **Player IDs**: String identifiers, not integers
5. **Timestamps**: Unix timestamps (milliseconds) for most time fields
6. **No Webhooks**: API is pull-only, no push notifications detected

## Recommendations for Sync Strategy

1. **Full League Sync**: Daily at 3 AM (low activity time)
2. **Roster Updates**: Every hour during season
3. **Live Scoring**: Every 5 minutes during game windows (Sun 1pm-11pm, Mon/Thu 8pm-11pm)
4. **Transactions**: Every 30 minutes during waivers (Wed 3am-6am typical)
5. **Player Metadata**: Weekly (Tuesdays after waivers clear)

## API Response Samples

Response samples have been saved to:
- `sample_league.json`
- `sample_users.json`
- `sample_rosters.json`
- `sample_matchups.json`
- `sample_transactions_week_*.json`
- `sample_draft.json`
- `sample_draft_picks.json`
- `sample_nfl_state.json`
