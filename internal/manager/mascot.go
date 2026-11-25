package manager

import (
	"strings"

	"github.com/NeoLabs-Systems/neolabs-go/cli"
)

// The NeoAgent face: a 9×9 dot matrix on a near-black screen inside a rounded
// rim, gold where lit. These faces are the same frames the landing page
// (landing/js/mascot.js), the app and the wearable firmware draw.
const blankRow = "........."

var faces = map[string][]string{
	"idle": {blankRow, blankRow, "..##.##..", "..##.##..", "..##.##..", blankRow, blankRow, blankRow, blankRow},
	"done": {blankRow, blankRow, "..#...#..", ".#.#.#.#.", blankRow, blankRow, "..#...#..", "...###...", blankRow},
}

// renderFace draws a face. A dot and the space after it are about square in a
// terminal cell. The rim is drawn with half and quarter blocks, so it is half
// a cell thick and its corners round off.
func renderFace(u *cli.UI, name string) []string {
	rows := faces[name]
	if u.Depth == 0 {
		lines := []string{"╭" + strings.Repeat("─", 19) + "╮"}
		for _, row := range rows {
			cells := make([]string, len(row))
			for i, c := range row {
				cells[i] = map[bool]string{true: "●", false: "·"}[c == '#']
			}
			lines = append(lines, "│ "+strings.Join(cells, " ")+" │")
		}
		return append(lines, "╰"+strings.Repeat("─", 19)+"╯")
	}
	rim := func(s string) string { return u.SGR(u.Foreground("rim"), s) }
	screen := u.Background("screen")
	dot := func(c rune) string {
		if c == '#' {
			return "\x1b[1;" + u.Foreground("accent") + "m●"
		}
		return "\x1b[22;" + u.Foreground("unlit") + "m·"
	}
	lines := []string{rim("▗" + strings.Repeat("▄", 19) + "▖")}
	for _, row := range rows {
		cells := make([]string, 0, len(row))
		for _, c := range row {
			cells = append(cells, dot(c))
		}
		lines = append(lines, rim("▐")+"\x1b["+screen+"m "+strings.Join(cells, " ")+" \x1b[0m"+rim("▌"))
	}
	return append(lines, rim("▝"+strings.Repeat("▀", 19)+"▘"))
}
