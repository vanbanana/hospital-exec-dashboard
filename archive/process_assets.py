# 历史资产留档（非工程代码）：早期大屏视觉稿的边缘融合工具——把生图资产按
# smootherstep 羽化蒙版融进 #0b1325 深蓝底，供 archive/smart-hospital-cockpit/
# 参考工程的 public/assets 出图。脚本内路径为当时 Windows 本机路径，不可直接运行。
import os
from PIL import Image
import numpy as np

# Target background color: #0b1325 -> (11, 19, 37)
TARGET_BG = np.array([11, 19, 37], dtype=np.float32)

def blend_to_target(img_path, out_path, margin_x=140, margin_top=100, margin_bottom=120):
    im = Image.open(img_path).convert('RGB')
    arr = np.array(im, dtype=np.float32)
    h, w, _ = arr.shape

    # 1. Create a 2D smooth edge vignette mask [0, 1]
    # 1 means keep original, 0 means blend to TARGET_BG
    x = np.linspace(0, 1, w)
    y = np.linspace(0, 1, h)
    xx, yy = np.meshgrid(x, y)

    # Distances to borders normalized by margins
    dist_l = np.clip((xx * w) / margin_x, 0, 1)
    dist_r = np.clip(((1.0 - xx) * w) / margin_x, 0, 1)
    dist_t = np.clip((yy * h) / margin_top, 0, 1)
    dist_b = np.clip(((1.0 - yy) * h) / margin_bottom, 0, 1)

    # Quintic smootherstep interpolation: 6t^5 - 15t^4 + 10t^3 (C2 continuity, zero slope/crease at edges)
    def smootherstep(t):
        return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)

    mask_x = smootherstep(np.minimum(dist_l, dist_r))
    mask_y = smootherstep(np.minimum(dist_t, dist_b))
    edge_mask = (mask_x * mask_y)[:, :, np.newaxis]

    # Blend with target background (#0b1325)
    blended = arr * edge_mask + TARGET_BG * (1.0 - edge_mask)
    blended = np.clip(blended, 0, 255).astype(np.uint8)

    out_im = Image.fromarray(blended)
    out_im.save(out_path, 'JPEG', quality=98, subsampling=0)
    print(f'Successfully processed {os.path.basename(img_path)} -> {out_path}')

if __name__ == '__main__':
    # Newly generated high-fidelity assets (Zero AI text hallucination, zero neon purple, PBR realism)
    images_config = {
        'hospital_campus.jpg': {
            'src': r'C:\Users\20304\.gemini\antigravity\brain\e5af7073-23b1-436c-ada1-91682ba7883a\hospital_campus_1789953573369.jpg',
            'mx': 140, 'mt': 100, 'mb': 120
        },
        'hospital_facade.jpg': {
            'src': r'C:\Users\20304\.gemini\antigravity\brain\e5af7073-23b1-436c-ada1-91682ba7883a\hospital_facade_1789953666756.jpg',
            'mx': 160, 'mt': 110, 'mb': 130
        },
        'hospital_floor_wireframe.jpg': {
            'src': r'C:\Users\20304\.gemini\antigravity\brain\e5af7073-23b1-436c-ada1-91682ba7883a\hospital_wireframe_1789953691507.jpg',
            'mx': 140, 'mt': 100, 'mb': 120
        },
        'hospital_floors_stack.jpg': {
            'src': r'C:\Users\20304\.gemini\antigravity\brain\e5af7073-23b1-436c-ada1-91682ba7883a\hospital_stack_1789953720568.jpg',
            'mx': 160, 'mt': 110, 'mb': 130
        }
    }

    dest_dir = r'd:\测试区域文件夹\zuoye\smart-hospital-cockpit\public\assets'
    os.makedirs(dest_dir, exist_ok=True)

    for name, cfg in images_config.items():
        dst = os.path.join(dest_dir, name)
        blend_to_target(cfg['src'], dst, margin_x=cfg['mx'], margin_top=cfg['mt'], margin_bottom=cfg['mb'])
