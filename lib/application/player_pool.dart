// Player pool: owns every VideoPlayerController.
//
// - At most three live controllers: the current page and its neighbours.
// - Controllers outside that window are disposed.
// - A locked episode never gets a controller, not even a paused one.
//
// TODO: Implement.
