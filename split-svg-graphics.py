#!/usr/bin/env python3
"""
SVG Graphics Splitter - Backend for Raycast script.
Automatically detects visual groups in an SVG, splits them,
and exports each as a transparent 4K PNG.

Also separates background fills (non-dark shapes like parallelograms)
from foreground content when detected in a group.
"""

import xml.etree.ElementTree as ET
import copy, io, os, sys, re
import numpy as np

# cairosvg needs cairo lib path on macOS
cairo_lib = None
try:
    import subprocess
    result = subprocess.run(["brew", "--prefix", "cairo"], capture_output=True, text=True)
    if result.returncode == 0:
        cairo_lib = os.path.join(result.stdout.strip(), "lib")
        os.environ["DYLD_LIBRARY_PATH"] = cairo_lib
except Exception:
    pass

import cairosvg
from PIL import Image

# macOS Vision framework for local OCR
try:
    import Vision
    import Quartz
    from Foundation import NSData
    HAS_VISION = True
except ImportError:
    HAS_VISION = False

RENDER_SCALE = 10
TARGET_W = 3840
TARGET_H = 2160
MIN_GAP_PX = 15  # minimum gap in SVG coords to split groups


def render_svg(svg_bytes, width, height):
    """Render SVG bytes to RGBA PIL Image."""
    png_data = cairosvg.svg2png(bytestring=svg_bytes, output_width=width, output_height=height)
    return Image.open(io.BytesIO(png_data)).convert('RGBA')


def find_gaps(density, min_gap):
    """Find gaps (runs of zeros) in a 1D density array. Returns list of (start, end) tuples."""
    gaps = []
    in_gap = False
    start = 0
    for i, v in enumerate(density):
        if v == 0:
            if not in_gap:
                start = i
                in_gap = True
        else:
            if in_gap:
                if i - start >= min_gap:
                    gaps.append((start, i))
                in_gap = False
    if in_gap and len(density) - start >= min_gap:
        gaps.append((start, len(density)))
    return gaps


def bands_from_gaps(gaps, total_len):
    """Convert gap list into content bands."""
    bands = []
    prev_end = 0
    for gap_start, gap_end in gaps:
        if gap_start > prev_end:
            bands.append((prev_end, gap_start))
        prev_end = gap_end
    if prev_end < total_len:
        bands.append((prev_end, total_len))
    return bands


def detect_groups(alpha, svg_w, svg_h, max_depth=3):
    """Auto-detect visual groups by recursively splitting rows and columns."""
    S = alpha.shape[0] // svg_h
    min_gap = MIN_GAP_PX * S

    def split_region(region, ox, oy, depth=0):
        """Recursively split a region into groups. ox/oy are pixel offsets."""
        if depth >= max_depth:
            return [(ox, oy, ox + region.shape[1], oy + region.shape[0])]

        h, w = region.shape

        # Try horizontal split first
        row_density = np.sum(region > 0, axis=1)
        h_gaps = find_gaps(row_density, min_gap)
        h_bands = bands_from_gaps(h_gaps, h)

        if len(h_bands) > 1:
            # Split into rows, then recurse on each
            results = []
            for ry1, ry2 in h_bands:
                sub = region[ry1:ry2, :]
                results.extend(split_region(sub, ox, oy + ry1, depth + 1))
            return results

        # Try vertical split
        col_density = np.sum(region > 0, axis=0)
        v_gaps = find_gaps(col_density, min_gap)
        v_bands = bands_from_gaps(v_gaps, w)

        if len(v_bands) > 1:
            # Split into columns, then recurse on each
            results = []
            for cx1, cx2 in v_bands:
                sub = region[:, cx1:cx2]
                results.extend(split_region(sub, ox + cx1, oy, depth + 1))
            return results

        # No more splits possible - this is a leaf group
        return [(ox, oy, ox + w, oy + h)]

    pixel_groups = split_region(alpha, 0, 0)

    # Convert pixel coords to SVG coords
    return [(x1 // S, y1 // S, x2 // S, y2 // S) for x1, y1, x2, y2 in pixel_groups]


def auto_trim_and_scale(img, target_w, target_h, pad=20):
    """Auto-trim transparent edges, fit content onto exact target_w x target_h canvas."""
    arr = np.array(img)
    alpha = arr[:, :, 3]
    rows = np.any(alpha > 0, axis=1)
    cols = np.any(alpha > 0, axis=0)

    if not np.any(rows) or not np.any(cols):
        return None

    r1, r2 = np.where(rows)[0][[0, -1]]
    c1, c2 = np.where(cols)[0][[0, -1]]

    r1 = max(0, r1 - pad)
    c1 = max(0, c1 - pad)
    r2 = min(img.height - 1, r2 + pad)
    c2 = min(img.width - 1, c2 + pad)

    trimmed = img.crop((c1, r1, c2 + 1, r2 + 1))

    w, h = trimmed.size
    scale = min(target_w / w, target_h / h)
    new_w, new_h = int(w * scale), int(h * scale)

    scaled = trimmed.resize((new_w, new_h), Image.LANCZOS)

    # Place centered on a transparent canvas at exact target dimensions
    canvas = Image.new('RGBA', (target_w, target_h), (0, 0, 0, 0))
    offset_x = (target_w - new_w) // 2
    offset_y = (target_h - new_h) // 2
    canvas.paste(scaled, (offset_x, offset_y))

    return canvas


def find_background_elements(root):
    """Find elements with light fills that could be backgrounds."""
    ns = root.tag.split('}')[0] + '}' if '}' in root.tag else ''

    # Parse style classes
    fill_map = {}
    for elem in root.iter():
        tag = elem.tag.split('}')[-1]
        if tag == 'style' and elem.text:
            for m in re.finditer(r'\.(cls-\d+)\{([^}]+)\}', elem.text):
                cls_name = m.group(1)
                props = m.group(2)
                fill_match = re.search(r'fill:\s*(#[0-9a-fA-F]+)', props)
                if fill_match:
                    fill_map[cls_name] = fill_match.group(1)

    # Find elements with light fills
    bg_elements = []
    children = list(root)
    for i, child in enumerate(children):
        tag = child.tag.split('}')[-1]
        cls = child.get('class', '')
        fill = child.get('fill', '')

        # Check inline fill
        if not fill and cls in fill_map:
            fill = fill_map[cls]

        if fill:
            # Check if it's a light color (not black/dark)
            try:
                r = int(fill[1:3], 16)
                g = int(fill[3:5], 16)
                b = int(fill[5:7], 16)
                brightness = (r + g + b) / 3
                if brightness > 150:  # light fill = likely background
                    bg_elements.append((i, tag, fill))
            except (ValueError, IndexError):
                pass

    return bg_elements


def ocr_image(pil_img):
    """Run local macOS Vision OCR on a PIL image. Returns recognized text."""
    if not HAS_VISION:
        return ""

    # Composite onto white background (Vision needs opaque images)
    rgba = pil_img.convert("RGBA")
    bg = Image.new("RGBA", rgba.size, (255, 255, 255, 255))
    bg.paste(rgba, mask=rgba)
    rgb = bg.convert("RGB")

    buf = io.BytesIO()
    rgb.save(buf, format="JPEG", quality=90)
    jpeg_data = buf.getvalue()

    ns_data = NSData.dataWithBytes_length_(jpeg_data, len(jpeg_data))
    source = Quartz.CGImageSourceCreateWithData(ns_data, None)
    if not source:
        return ""
    image = Quartz.CGImageSourceCreateImageAtIndex(source, 0, None)
    if not image:
        return ""

    handler = Vision.VNImageRequestHandler.alloc().initWithCGImage_options_(image, None)
    request = Vision.VNRecognizeTextRequest.alloc().init()
    request.setRecognitionLevel_(Vision.VNRequestTextRecognitionLevelAccurate)

    success, error = handler.performRequests_error_([request], None)
    if not success:
        return ""

    texts = []
    for obs in request.results():
        candidate = obs.topCandidates_(1)
        if candidate:
            texts.append(candidate[0].string())
    return " ".join(texts)


def text_to_filename(text, max_len=60):
    """Convert OCR text to a clean kebab-case filename."""
    if not text:
        return ""
    # Lowercase, replace special chars
    clean = text.lower()
    clean = clean.replace('$', '').replace('%', 'pct').replace('&', 'and')
    clean = clean.replace(',', '').replace('.', '').replace('-', ' ')
    # Keep only alphanumeric and spaces
    clean = re.sub(r'[^a-z0-9 ]', '', clean)
    # Collapse whitespace, convert to underscores
    clean = re.sub(r'\s+', '_', clean.strip())
    # Trim to max length at word boundary
    if len(clean) > max_len:
        clean = clean[:max_len].rsplit('_', 1)[0]
    return clean


def export_group(full_img, crop_box, scale, name, output_dir):
    """Crop a group from the full render and export. Returns (size, path)."""
    x1, y1, x2, y2 = [int(c * scale) for c in crop_box]
    crop = full_img.crop((x1, y1, x2, y2))
    final = auto_trim_and_scale(crop, TARGET_W, TARGET_H)

    if final is None:
        return None, None

    out_path = os.path.join(output_dir, f"{name}.png")
    final.save(out_path, 'PNG')
    return final.size, out_path


def main():
    if len(sys.argv) < 2:
        print("Usage: split-svg-graphics.py <svg_file>")
        sys.exit(1)

    svg_path = sys.argv[1]
    if not os.path.exists(svg_path):
        print(f"File not found: {svg_path}")
        sys.exit(1)

    base_name = os.path.splitext(os.path.basename(svg_path))[0]
    output_dir = os.path.join(os.path.dirname(svg_path), f"{base_name}_Export")
    os.makedirs(output_dir, exist_ok=True)

    print(f"Processing: {svg_path}")
    print(f"Output: {output_dir}")

    # Parse SVG to get dimensions
    tree = ET.parse(svg_path)
    root = tree.getroot()
    ET.register_namespace('', 'http://www.w3.org/2000/svg')

    viewbox = root.get('viewBox', '0 0 864 864')
    vb_parts = viewbox.split()
    svg_w, svg_h = int(float(vb_parts[2])), int(float(vb_parts[3]))
    render_w = svg_w * RENDER_SCALE
    render_h = svg_h * RENDER_SCALE

    # Render full SVG
    svg_bytes = ET.tostring(root, encoding='unicode', xml_declaration=True).encode()
    print(f"Rendering at {render_w}x{render_h}...")
    full_img = render_svg(svg_bytes, render_w, render_h)

    # Check for background elements early (affects detection strategy)
    bg_elements = find_background_elements(root)
    has_bg = len(bg_elements) > 0

    # Build foreground-only render if backgrounds exist
    fg_img = None
    bg_img = None
    if has_bg:
        print(f"Found {len(bg_elements)} background element(s) - separating layers")

        # Build set of bg element identities using index in original children
        bg_indices = set(bi for bi, bt, bf in bg_elements)
        orig_children = list(root)

        # Foreground only (remove bg elements by index)
        root_fg = copy.deepcopy(root)
        fg_children = list(root_fg)
        for i in sorted(bg_indices, reverse=True):
            if i < len(fg_children):
                root_fg.remove(fg_children[i])

        svg_fg = ET.tostring(root_fg, encoding='unicode', xml_declaration=True).encode()
        fg_img = render_svg(svg_fg, render_w, render_h)

        # Background only (keep only bg elements + defs)
        root_bg = copy.deepcopy(root)
        bg_children = list(root_bg)
        to_remove = []
        for i, child in enumerate(bg_children):
            tag = child.tag.split('}')[-1]
            if tag == 'defs':
                continue
            if i not in bg_indices:
                to_remove.append(child)
        for child in to_remove:
            root_bg.remove(child)

        svg_bg = ET.tostring(root_bg, encoding='unicode', xml_declaration=True).encode()
        bg_img = render_svg(svg_bg, render_w, render_h)

    # Detect groups using foreground-only render if available (cleaner gaps)
    detect_img = fg_img if fg_img else full_img
    alpha = np.array(detect_img)[:, :, 3]
    groups = detect_groups(alpha, svg_w, svg_h)
    print(f"Detected {len(groups)} groups")

    # Export each group, OCR for naming, then rename
    if HAS_VISION:
        print("Using macOS Vision for OCR-based naming...")
    else:
        print("Vision framework not available - using coordinate-based names")

    used_names = set()
    for idx, (x1, y1, x2, y2) in enumerate(groups):
        # Export with temp name first
        temp_name = f"{idx+1:02d}_temp"
        size, path = export_group(full_img, (x1, y1, x2, y2), RENDER_SCALE, temp_name, output_dir)
        if not size or not path:
            continue

        # OCR the exported image
        ocr_text = ""
        if HAS_VISION and path:
            exported = Image.open(path)
            ocr_text = ocr_image(exported)

        # Build final filename
        slug = text_to_filename(ocr_text)
        if slug:
            final_name = f"{idx+1:02d}_{slug}"
        else:
            final_name = f"{idx+1:02d}_graphic"

        # Deduplicate
        base_final = final_name
        counter = 2
        while final_name in used_names:
            final_name = f"{base_final}_{counter}"
            counter += 1
        used_names.add(final_name)

        # Rename
        final_path = os.path.join(output_dir, f"{final_name}.png")
        os.rename(path, final_path)
        print(f"  {final_name}.png ({size[0]}x{size[1]})" + (f"  <- \"{ocr_text}\"" if ocr_text else ""))

    # For groups containing backgrounds, export separated foreground/background
    if has_bg:
        print("\nSeparating backgrounds...")
        bg_alpha = np.array(bg_img)[:, :, 3]

        for idx, (x1, y1, x2, y2) in enumerate(groups):
            px1, py1 = int(x1 * RENDER_SCALE), int(y1 * RENDER_SCALE)
            px2, py2 = int(x2 * RENDER_SCALE), int(y2 * RENDER_SCALE)
            region_bg = bg_alpha[py1:py2, px1:px2]

            if np.any(region_bg > 0):
                # Use OCR on the foreground version for naming
                temp_fg = f"{idx+1:02d}_fg_temp"
                temp_bg = f"{idx+1:02d}_bg_temp"

                size_fg, path_fg = export_group(fg_img, (x1, y1, x2, y2), RENDER_SCALE, temp_fg, output_dir)
                size_bg, path_bg = export_group(bg_img, (x1, y1, x2, y2), RENDER_SCALE, temp_bg, output_dir)

                # OCR the foreground for naming
                fg_text = ""
                if HAS_VISION and path_fg:
                    fg_text = ocr_image(Image.open(path_fg))
                slug = text_to_filename(fg_text) or "graphic"

                if size_fg and path_fg:
                    fg_name = f"{idx+1:02d}_{slug}_foreground"
                    fg_final = os.path.join(output_dir, f"{fg_name}.png")
                    os.rename(path_fg, fg_final)
                    print(f"  {fg_name}.png ({size_fg[0]}x{size_fg[1]})")

                if size_bg and path_bg:
                    bg_name = f"{idx+1:02d}_{slug}_background"
                    bg_final = os.path.join(output_dir, f"{bg_name}.png")
                    os.rename(path_bg, bg_final)
                    print(f"  {bg_name}.png ({size_bg[0]}x{size_bg[1]})")

    # Count outputs
    exports = [f for f in os.listdir(output_dir) if f.endswith('.png')]
    print(f"\nDone! Exported {len(exports)} PNGs to {output_dir}")


if __name__ == '__main__':
    main()
