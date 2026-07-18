"""
OCR processing for receipt images.

Preprocesses captured frames and runs Tesseract OCR to extract text.
Includes deduplication for overlapping frame regions.
"""

from PIL import Image, ImageFilter, ImageOps
import pytesseract
import numpy as np


# Tesseract config: PSM 4 = assume a single column of variable-size text
# (better for receipts than PSM 6), LSTM engine only, and a tighter
# whitelist that drops the noisy symbols that produce junk tokens.
TESSERACT_CONFIG = (
    "--oem 1 --psm 4 "
    "-c preserve_interword_spaces=1 "
    "-c tessedit_char_whitelist="
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.$/@ "
)

# Target DPI for OCR (Tesseract works best at 300 DPI)
TARGET_DPI = 300

# Overlap deduplication: if two lines match this fraction of chars, deduplicate
DEDUP_SIMILARITY_THRESHOLD = 0.8


def preprocess_image(img):
    """
    Preprocess a receipt image for optimal OCR accuracy.

    Pipeline:
    1. Convert to grayscale
    2. Scale up to ~300 DPI equivalent
    3. Apply adaptive thresholding (binary)
    4. Denoise with median filter
    5. Sharpen
    """
    # 1. Grayscale
    gray = img.convert("L")

    # 2. Scale up if small (assume ~150 DPI input from Pi Camera)
    w, h = gray.size
    scale = max(1, TARGET_DPI / 150)
    if scale > 1:
        gray = gray.resize((int(w * scale), int(h * scale)), Image.LANCZOS)

    # 3. Adaptive threshold via numpy (Pillow doesn't have adaptive threshold)
    arr = np.array(gray, dtype=np.float32)
    # Local mean filter with a 31-pixel window
    kernel_size = 31
    from PIL import ImageFilter as IF

    blurred = gray.filter(IF.BoxBlur(kernel_size // 2))
    blurred_arr = np.array(blurred, dtype=np.float32)

    # Threshold: pixel is black if it's darker than local mean minus offset
    offset = 15
    binary_arr = np.where(arr < blurred_arr - offset, 0, 255).astype(np.uint8)
    binary = Image.fromarray(binary_arr)

    # 4. Denoise
    binary = binary.filter(ImageFilter.MedianFilter(size=3))

    # 5. Sharpen
    binary = binary.filter(ImageFilter.SHARPEN)

    return binary


def ocr_image(img):
    """Run Tesseract OCR on a preprocessed image and return raw text."""
    processed = preprocess_image(img)
    text = pytesseract.image_to_string(processed, config=TESSERACT_CONFIG)
    return text


def _line_similarity(a, b):
    """Simple character-level similarity ratio between two strings."""
    if not a or not b:
        return 0.0
    a, b = a.strip().lower(), b.strip().lower()
    if a == b:
        return 1.0
    shorter, longer = (a, b) if len(a) <= len(b) else (b, a)
    matches = sum(1 for c1, c2 in zip(shorter, longer) if c1 == c2)
    return matches / max(len(longer), 1)


def deduplicate_lines(lines, threshold=DEDUP_SIMILARITY_THRESHOLD):
    """
    Remove duplicate lines caused by overlapping frame captures.
    Consecutive similar lines are merged (keeps the first occurrence).
    """
    if not lines:
        return lines

    result = [lines[0]]
    for line in lines[1:]:
        if _line_similarity(line, result[-1]) < threshold:
            result.append(line)
    return result


def ocr_receipt(frames):
    """
    Process all captured frames through OCR, concatenate text,
    and deduplicate lines from overlapping regions.

    Args:
        frames: list of PIL Image objects

    Returns:
        Full receipt text as a single string
    """
    all_lines = []

    for i, frame in enumerate(frames):
        print(f"[ocr] Processing frame {i + 1}/{len(frames)}...")
        text = ocr_image(frame)
        frame_lines = [l for l in text.split("\n") if l.strip()]
        all_lines.extend(frame_lines)

    # Deduplicate overlapping lines
    deduped = deduplicate_lines(all_lines)
    full_text = "\n".join(deduped)

    print(f"[ocr] Extracted {len(deduped)} lines from {len(frames)} frames")
    return full_text
