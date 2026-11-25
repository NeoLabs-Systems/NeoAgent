package ai

import (
	"context"
	"sync"
)

// DefaultMaxParallelToolCalls bounds how many read-only calls overlap.
const DefaultMaxParallelToolCalls = 10

// NormalizeParallelLimit keeps a configured limit between 1 and 32.
func NormalizeParallelLimit(value int) int {
	if value < 1 {
		return DefaultMaxParallelToolCalls
	}
	return min(value, 32)
}

// CallGroup is a run of calls that may overlap, or one call that runs alone.
type CallGroup[T any] struct {
	Parallel bool
	Calls    []T
}

// GroupToolCalls splits model-ordered calls into barriers: consecutive
// parallel-safe calls share a group, every other call runs alone.
func GroupToolCalls[T any](calls []T, parallelSafe func(T) bool) []CallGroup[T] {
	var groups []CallGroup[T]
	var parallel []T
	for _, call := range calls {
		if parallelSafe(call) {
			parallel = append(parallel, call)
			continue
		}
		if len(parallel) > 0 {
			groups = append(groups, CallGroup[T]{Parallel: true, Calls: parallel})
			parallel = nil
		}
		groups = append(groups, CallGroup[T]{Calls: []T{call}})
	}
	if len(parallel) > 0 {
		groups = append(groups, CallGroup[T]{Parallel: true, Calls: parallel})
	}
	return groups
}

// ScheduleToolCalls runs model-ordered tool calls with barriers. Consecutive
// parallel-safe calls share a bounded pool; other calls run alone; committed
// outcomes always follow model order. execute errors stop the schedule.
func ScheduleToolCalls[T, R any](ctx context.Context, calls []T, parallelSafe func(T) bool, execute func(context.Context, T) (R, error), commit func(R, T), maxParallel int) error {
	for _, group := range GroupToolCalls(calls, parallelSafe) {
		results := make([]R, len(group.Calls))
		if group.Parallel && len(group.Calls) > 1 {
			if err := runParallel(ctx, group.Calls, execute, results, NormalizeParallelLimit(maxParallel)); err != nil {
				return err
			}
		} else {
			result, err := execute(ctx, group.Calls[0])
			if err != nil {
				return err
			}
			results[0] = result
		}
		for i, result := range results {
			if commit != nil {
				commit(result, group.Calls[i])
			}
		}
	}
	return nil
}

func runParallel[T, R any](ctx context.Context, calls []T, execute func(context.Context, T) (R, error), results []R, limit int) error {
	var (
		mu      sync.Mutex
		next    int
		failure error
		wg      sync.WaitGroup
	)
	worker := func() {
		defer wg.Done()
		for {
			mu.Lock()
			if failure != nil || next >= len(calls) {
				mu.Unlock()
				return
			}
			index := next
			next++
			mu.Unlock()
			result, err := execute(ctx, calls[index])
			mu.Lock()
			if err != nil && failure == nil {
				failure = err
			}
			results[index] = result
			mu.Unlock()
		}
	}
	for i := 0; i < min(len(calls), limit); i++ {
		wg.Add(1)
		go worker()
	}
	wg.Wait()
	return failure
}
