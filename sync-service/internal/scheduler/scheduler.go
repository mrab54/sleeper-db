package scheduler

import (
	"time"

	"github.com/go-co-op/gocron"
	"github.com/mrab54/sleeper-db/sync-service/internal/sync"
	"go.uber.org/zap"
)

// Scheduler manages scheduled sync jobs
type Scheduler struct {
	scheduler *gocron.Scheduler
	syncer    *sync.Syncer
	logger    *zap.Logger
}

// NewScheduler creates a new scheduler
func NewScheduler(syncer *sync.Syncer, logger *zap.Logger) *Scheduler {
	s := gocron.NewScheduler(time.UTC)
	s.SingletonModeAll()

	return &Scheduler{
		scheduler: s,
		syncer:    syncer,
		logger:    logger,
	}
}

// Start starts the scheduler
func (s *Scheduler) Start() error {
	s.scheduler.StartAsync()
	s.logger.Info("Scheduler started")
	return nil
}

// Stop stops the scheduler
func (s *Scheduler) Stop() {
	s.scheduler.Stop()
	s.logger.Info("Scheduler stopped")
}

// AddCronJob adds a cron-scheduled job
func (s *Scheduler) AddCronJob(name, cronExpr string, fn func()) error {
	_, err := s.scheduler.Cron(cronExpr).Tag(name).Do(fn)
	if err != nil {
		s.logger.Error("Failed to add cron job",
			zap.String("name", name),
			zap.String("cron", cronExpr),
			zap.Error(err),
		)
		return err
	}

	s.logger.Info("Cron job added",
		zap.String("name", name),
		zap.String("cron", cronExpr),
	)
	return nil
}

// AddIntervalJob adds an interval-based job
func (s *Scheduler) AddIntervalJob(name string, interval time.Duration, fn func()) error {
	_, err := s.scheduler.Every(interval).Tag(name).Do(fn)
	if err != nil {
		s.logger.Error("Failed to add interval job",
			zap.String("name", name),
			zap.Duration("interval", interval),
			zap.Error(err),
		)
		return err
	}

	s.logger.Info("Interval job added",
		zap.String("name", name),
		zap.Duration("interval", interval),
	)
	return nil
}

// RemoveJob removes a job by tag
func (s *Scheduler) RemoveJob(tag string) error {
	err := s.scheduler.RemoveByTag(tag)
	if err != nil {
		s.logger.Error("Failed to remove job",
			zap.String("tag", tag),
			zap.Error(err),
		)
		return err
	}

	s.logger.Info("Job removed", zap.String("tag", tag))
	return nil
}

// Jobs returns all scheduled jobs
func (s *Scheduler) Jobs() []*gocron.Job {
	return s.scheduler.Jobs()
}

// NextRun returns the next run time for a job
func (s *Scheduler) NextRun(tag string) (time.Time, error) {
	jobs, err := s.scheduler.FindJobsByTag(tag)
	if err != nil || len(jobs) == 0 {
		return time.Time{}, err
	}
	return jobs[0].NextRun(), nil
}