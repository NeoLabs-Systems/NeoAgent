package ocr

import "testing"

func TestMeanConfidenceReadsWordRows(t *testing.T) {
	tsv := "level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext\n" +
		"1\t1\t0\t0\t0\t0\t0\t0\t100\t50\t-1\t\n" +
		"5\t1\t1\t1\t1\t1\t0\t0\t10\t10\t90\tHello\n" +
		"5\t1\t1\t1\t1\t2\t0\t0\t10\t10\t80.5\tworld\n" +
		"5\t1\t1\t1\t1\t3\t0\t0\t10\t10\t-1\t \n"
	if got := MeanConfidence(tsv); got != 85.25 {
		t.Fatalf("got %v", got)
	}
	if MeanConfidence("") != 0 {
		t.Fatal("empty output should be 0")
	}
}
