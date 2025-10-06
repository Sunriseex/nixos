package telegram

import (
	"sync"
	"time"
)

type StateManager struct {
	states map[int64]*UserState
	mu     sync.RWMutex
}
type UserState struct {
	CurrentState StateType
	Data         map[string]interface{}
	CreatedAt    time.Time
	LastActivity time.Time
}
type StateType string

const (
	StateNone             StateType = "none"
	StateAddingPayment    StateType = "adding_payment"
	StateAddingDeposit    StateType = "adding_deposit"
	StateWaitingForAmount StateType = "waiting_for_amount"
	StateWaitingForDate   StateType = "waiting_for_date"
)

func NewStateManager() *StateManager {
	sm := &StateManager{
		states: make(map[int64]*UserState),
	}
	go sm.cleanupRoutine()
	return sm
}

func (sm *StateManager) SetState(userID int64, state StateType, data map[string]interface{}) {
	sm.mu.Lock()
	defer sm.mu.Unlock()

	if data == nil {
		data = make(map[string]interface{})

	}
	sm.states[userID] = &UserState{
		CurrentState: state,
		Data:         data,
		CreatedAt:    time.Now(),
		LastActivity: time.Now(),
	}
}

func (sm *StateManager) GetState(userID int64) (*UserState, bool) {
	sm.mu.Lock()
	defer sm.mu.Unlock()
	state, exists := sm.states[userID]
	if exists {
		state.LastActivity = time.Now()
	}
	return state, exists
}
func (sm *StateManager) ClearState(userID int64) {
	sm.mu.Lock()
	defer sm.mu.Unlock()
	delete(sm.states, userID)
}

func (sm *StateManager) UpdateStateData(userID int64, key string, value interface{}) bool {
	sm.mu.Lock()
	defer sm.mu.Unlock()
	state, exists := sm.states[userID]
	if !exists {
		return false
	}
	if state.Data == nil {
		state.Data = make(map[string]interface{})
	}
	state.Data[key] = value
	state.LastActivity = time.Now()
	return true
}

func (sm *StateManager) cleanupRoutine() {
	ticker := time.NewTicker(30 * time.Minute)
	defer ticker.Stop()
	for range ticker.C {
		sm.cleanupExpiredStates()
	}
}

func (sm *StateManager) cleanupExpiredStates() {
	sm.mu.Lock()
	defer sm.mu.Unlock()
	now := time.Now()
	for userID, state := range sm.states {
		if now.Sub(state.LastActivity) > 30*time.Minute {
			delete(sm.states, userID)
		}
	}

}
