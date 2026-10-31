import glob
import os
import shutil
from PIL import Image

def make_gif(frame_dir, out_gif_path, duration=100, max_width=640):
    files = sorted(glob.glob(os.path.join(frame_dir, "*.png")))
    if not files:
        print(f"No frames found in {frame_dir}")
        return
    
    # Subsample frames if too many (to keep GIF lightweight)
    # Take at most ~30 frames
    step = max(1, len(files) // 30)
    selected_files = files[::step]
    if files[-1] not in selected_files:
        selected_files.append(files[-1])

    frames = []
    for f in selected_files:
        with Image.open(f) as img:
            # Resize proportionally to max_width to keep file compact
            if img.width > max_width:
                h = int(img.height * (max_width / img.width))
                resized = img.resize((max_width, h), Image.Resampling.LANCZOS)
                # Convert to adaptive 256 palette for crisp GIF rendering
                frames.append(resized.convert("P", palette=Image.Palette.ADAPTIVE))
            else:
                frames.append(img.convert("P", palette=Image.Palette.ADAPTIVE))
    
    if frames:
        frames[0].save(
            out_gif_path,
            save_all=True,
            append_images=frames[1:],
            optimize=True,
            duration=duration,
            loop=0
        )
        print(f"Saved animated GIF: {out_gif_path} ({len(frames)} frames, {os.path.getsize(out_gif_path) // 1024} KB)")

if __name__ == "__main__":
    base_dir = "tools/screenshots"
    make_gif(os.path.join(base_dir, "player_duel_frames"), os.path.join(base_dir, "player_duel_flow.gif"), duration=120)
    make_gif(os.path.join(base_dir, "compact_duel_frames"), os.path.join(base_dir, "compact_ai_duel.gif"), duration=100)

    # Clean up frame directories
    shutil.rmtree(os.path.join(base_dir, "player_duel_frames"), ignore_errors=True)
    shutil.rmtree(os.path.join(base_dir, "compact_duel_frames"), ignore_errors=True)
    print("Cleaned up temporary frame directories.")
