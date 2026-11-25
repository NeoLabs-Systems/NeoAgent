package runtime

import "github.com/NeoLabs-Systems/neoagent/internal/jsonobj"

// Object is an ordered JSON object, the shape of statuses, readiness reports
// and guest answers.
type Object = jsonobj.Object

type omap = jsonobj.Object

// NewObject builds an Object from alternating keys and values.
func NewObject(pairs ...any) *Object { return jsonobj.New(pairs...) }

func obj(pairs ...any) *omap { return jsonobj.New(pairs...) }

func newOmap() *omap { return jsonobj.New() }
