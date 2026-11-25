package skills

import "strings"

// localeLess approximates String.prototype.localeCompare for the names and
// categories skills carry: letters compare without regard to case, and on a
// tie the lower case one comes first. Skill names are limited to a-z, 0-9 and
// hyphen, where this is exact.
func localeLess(a, b string) bool {
	la, lb := strings.ToLower(a), strings.ToLower(b)
	if la != lb {
		return la < lb
	}
	return a > b
}
