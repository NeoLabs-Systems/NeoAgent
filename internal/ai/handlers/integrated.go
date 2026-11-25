package handlers

import "context"

// integrated runs the integrated tools: NeoAgent's own settings and the
// SynthID detector. ok=false hands the call on to the built-in handlers.
func (b *Backend) integrated(ctx context.Context, c *call) (any, bool, error) {
	switch c.name {
	case "settings_read", "settings_update", "settings_link":
		s := b.d.Settings
		if s == nil {
			return errResult("NeoAgent settings are unavailable."), true, nil
		}
		var result any
		var err error
		switch c.name {
		case "settings_read":
			result, err = s.Read(ctx, c.run.UserID, c.run.AgentID, c.args)
		case "settings_update":
			result, err = s.Update(ctx, c.run.UserID, c.run.AgentID, c.args)
		default:
			result, err = s.Link(ctx, c.args)
		}
		return result, true, err
	case "detect_synthid_watermark":
		if b.d.SynthID == nil {
			return errResult("SynthID detection is unavailable."), true, nil
		}
		path, err := c.resolveUserFile(ctx, c.args["image_path"], "Image")
		if err != nil {
			return nil, true, err
		}
		result, err := b.d.SynthID.Detect(ctx, c.run.UserID, path)
		return result, true, err
	}
	return nil, false, nil
}
