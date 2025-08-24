package api

import (
	"encoding/json"
	"time"
)

// User represents a Sleeper user
type User struct {
	UserID      string          `json:"user_id"`
	Username    string          `json:"username"`
	DisplayName string          `json:"display_name"`
	Avatar      string          `json:"avatar"`
	Metadata    json.RawMessage `json:"metadata"`
	IsBot       bool            `json:"is_bot"`
}

// League represents a Sleeper league
type League struct {
	LeagueID          string          `json:"league_id"`
	Name              string          `json:"name"`
	Season            string          `json:"season"`
	Status            string          `json:"status"`
	Sport             string          `json:"sport"`
	TotalRosters      int             `json:"total_rosters"`
	RosterPositions   []string        `json:"roster_positions"`
	Settings          json.RawMessage `json:"settings"`
	ScoringSettings   json.RawMessage `json:"scoring_settings"`
	Metadata          json.RawMessage `json:"metadata"`
	SeasonType        string          `json:"season_type"`
	DraftID           string          `json:"draft_id"`
	PreviousLeagueID  string          `json:"previous_league_id"`
	BracketID         interface{}     `json:"bracket_id"`
	LoserBracketID    interface{}     `json:"loser_bracket_id"`
	GroupID           interface{}     `json:"group_id"`
	LastMessageID     string          `json:"last_message_id"`
	LastMessageTime   int64           `json:"last_message_time"`
	LastTransactionID string          `json:"last_transaction_id"`
	LastAuthorID      string          `json:"last_author_id"`
	LastAuthorIsBot   bool            `json:"last_author_is_bot"`
	LastAuthorAvatar  string          `json:"last_author_avatar"`
	LastPinnedMessageID string        `json:"last_pinned_message_id"`
	LastReadID        string          `json:"last_read_id"`
	CompanyID         interface{}     `json:"company_id"`
}

// Roster represents a team roster in a league
type Roster struct {
	RosterID   int             `json:"roster_id"`
	OwnerID    string          `json:"owner_id"`
	LeagueID   string          `json:"league_id"`
	Players    []string        `json:"players"`
	Starters   []string        `json:"starters"`
	Reserve    []string        `json:"reserve"`
	Taxi       []string        `json:"taxi"`
	CoOwners   []string        `json:"co_owners"`
	Settings   json.RawMessage `json:"settings"`
	Metadata   json.RawMessage `json:"metadata"`
	Keepers    []string        `json:"keepers"`
}

// RosterSettings contains win/loss record and points
type RosterSettings struct {
	Wins             int     `json:"wins"`
	Losses           int     `json:"losses"`
	Ties             int     `json:"ties"`
	WaiverPosition   int     `json:"waiver_position"`
	WaiverBudgetUsed int     `json:"waiver_budget_used"`
	TotalMoves       int     `json:"total_moves"`
	Division         int     `json:"division"`
	Fpts             float64 `json:"fpts"`
	FptsDecimal      float64 `json:"fpts_decimal"`
	FptsAgainst      float64 `json:"fpts_against"`
	FptsAgainstDecimal float64 `json:"fpts_against_decimal"`
	Ppts             float64 `json:"ppts"`
	PptsDecimal      float64 `json:"ppts_decimal"`
}

// Matchup represents a weekly matchup
type Matchup struct {
	RosterID      int                    `json:"roster_id"`
	MatchupID     int                    `json:"matchup_id"`
	Points        float64                `json:"points"`
	CustomPoints  float64                `json:"custom_points"`
	Starters      []string               `json:"starters"`
	StartersPoints []float64             `json:"starters_points"`
	PlayersPoints map[string]float64     `json:"players_points"`
}

// Transaction represents a league transaction
type Transaction struct {
	TransactionID   string          `json:"transaction_id"`
	Type            string          `json:"type"`
	TransactionType string          `json:"transaction_type"`
	Status          string          `json:"status"`
	StatusUpdated   int64           `json:"status_updated"`
	RosterIDs       []int           `json:"roster_ids"`
	Settings        json.RawMessage `json:"settings"`
	Adds            map[string]int  `json:"adds"`
	Drops           map[string]int  `json:"drops"`
	DraftPicks      []DraftPick     `json:"draft_picks"`
	WaiverBudget    []WaiverBudget  `json:"waiver_budget"`
	Metadata        json.RawMessage `json:"metadata"`
	Creator         string          `json:"creator"`
	Created         int64           `json:"created"`
	Leg             int             `json:"leg"`
}

// Player represents an NFL player
type Player struct {
	PlayerID             string   `json:"player_id"`
	FirstName            string   `json:"first_name"`
	LastName             string   `json:"last_name"`
	FullName             string   `json:"full_name"`
	Position             string   `json:"position"`
	Team                 string   `json:"team"`
	Age                  int      `json:"age"`
	YearsExp             int      `json:"years_exp"`
	College              string   `json:"college"`
	Weight               string   `json:"weight"`
	Height               string   `json:"height"`
	BirthDate            string   `json:"birth_date"`
	BirthCountry         string   `json:"birth_country"`
	BirthState           string   `json:"birth_state"`
	BirthCity            string   `json:"birth_city"`
	HighSchool           string   `json:"high_school"`
	DepthChartPosition   string   `json:"depth_chart_position"`
	DepthChartOrder      int      `json:"depth_chart_order"`
	GsisID               string   `json:"gsis_id"`
	EspnID               string   `json:"espn_id"`
	YahooID              string   `json:"yahoo_id"`
	FantasyDataID        int      `json:"fantasy_data_id"`
	Number               int      `json:"number"`
	InjuryStatus         string   `json:"injury_status"`
	InjuryBodyPart       string   `json:"injury_body_part"`
	InjuryStartDate      string   `json:"injury_start_date"`
	InjuryNotes          string   `json:"injury_notes"`
	PracticeParticipation string  `json:"practice_participation"`
	PracticeDescription  string   `json:"practice_description"`
	News                 []string `json:"news"`
	Status               string   `json:"status"`
	Sport                string   `json:"sport"`
	Active               bool     `json:"active"`
	SearchFirstName      string   `json:"search_first_name"`
	SearchLastName       string   `json:"search_last_name"`
	SearchFullName       string   `json:"search_full_name"`
	SearchRank           int      `json:"search_rank"`
	FantasyPositions     []string `json:"fantasy_positions"`
	Stats                map[string]map[string]interface{} `json:"stats"`
	Metadata             json.RawMessage `json:"metadata"`
}

// NFLState represents the current state of the NFL
type NFLState struct {
	Week               int    `json:"week"`
	SeasonType         string `json:"season_type"`
	Season             string `json:"season"`
	PreviousSeason     string `json:"previous_season"`
	SeasonStartDate    string `json:"season_start_date"`
	Leg                int    `json:"leg"`
	LeagueSeason       string `json:"league_season"`
	LeagueCreateSeason string `json:"league_create_season"`
	DisplayWeek        int    `json:"display_week"`
}

// DraftPick represents a draft pick in a trade
type DraftPick struct {
	Season          string `json:"season"`
	Round           int    `json:"round"`
	RosterID        int    `json:"roster_id"`
	PreviousOwnerID int    `json:"previous_owner_id"`
	OwnerID         int    `json:"owner_id"`
}

// TradedPick represents a traded draft pick
type TradedPick struct {
	Season          string `json:"season"`
	Round           int    `json:"round"`
	RosterID        int    `json:"roster_id"`
	PreviousOwnerID int    `json:"previous_owner_id"`
	OwnerID         int    `json:"owner_id"`
}

// WaiverBudget represents waiver budget in a trade
type WaiverBudget struct {
	Sender   int `json:"sender"`
	Receiver int `json:"receiver"`
	Amount   int `json:"amount"`
}

// Helper function to parse timestamps
func ParseSleeperTime(timestamp int64) time.Time {
	return time.Unix(timestamp/1000, (timestamp%1000)*1000000)
}