#!/usr/bin/env node

const fs = require("fs");

const buf = fs.readFileSync("960m.bin");

const slices = [];

slices[0] = buf.slice(0, 2**15);
slices[1] = buf.slice(2**15, 2**16);
slices[2] = buf.slice(2**16, 2**15 + 2**16);
slices[3] = buf.slice(2**15 + 2**16, buf.length);

const ITEMS_PER_LINE = 10;

slices.forEach((slice, sliceIdx) => {
  const lines = slice.reduce((acc, x, i) => {
    const lineIdx = Math.floor(i / ITEMS_PER_LINE);

    let line = acc[lineIdx];

    if (!line) {
      line = [];

      acc[lineIdx] = line;
    }

    line.push(`0x${x.toString(16).padStart(2, "0")}`);

    return acc;
  }, []);

  const str = lines.map(line => line.join(", ")).join(",\n");

  fs.writeFileSync(`slice-${sliceIdx}`, str);
});
