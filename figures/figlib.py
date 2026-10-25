"""Shared drawing helpers for Book 4 figures: series colors, boxes, arrows and a geometry check."""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch, Rectangle

B1, B2, LIGHT, GREY, INK, MID = '#1F4E79', '#2E74B5', '#D9E2F1', '#F2F2F2', '#222222', '#999999'
plt.rcParams['font.family'] = 'DejaVu Sans'


def canvas(w_in, h_in, xmax, ymax):
    fig, ax = plt.subplots(figsize=(w_in, h_in), dpi=200)
    fig.subplots_adjust(0, 0, 1, 1)
    ax.set_xlim(0, xmax); ax.set_ylim(0, ymax); ax.axis('off')
    return fig, ax


def box(ax, x, y, w, h, fc, ec, text, color=INK, size=8, weight='normal', family=None, ha='center', ls='-'):
    p = FancyBboxPatch((x, y), w, h, boxstyle='round,pad=0,rounding_size=0.08', fc=fc, ec=ec, lw=1.2, ls=ls)
    ax.add_patch(p)
    tx = x + w / 2 if ha == 'center' else x + 0.15
    t = ax.text(tx, y + h / 2, text, ha=ha, va='center', fontsize=size, color=color, weight=weight,
                family=family, linespacing=1.3)
    return p, t


def frame(ax, x, y, w, h, title, ec=B1, size=8.5):
    """An unfilled container with its title inside the top edge; returns (patch, title text)."""
    p = FancyBboxPatch((x, y), w, h, boxstyle='round,pad=0,rounding_size=0.1', fc='none', ec=ec, lw=1.4)
    ax.add_patch(p)
    t = ax.text(x + 0.15, y + h - 0.12, title, ha='left', va='top', fontsize=size, weight='bold', color=ec)
    return p, t


def arrow(ax, a, b, color=B2, style='-|>', lw=1.2, ls='-', rad=0.0):
    ax.add_patch(FancyArrowPatch(a, b, arrowstyle=style, mutation_scale=11, lw=lw, color=color, ls=ls,
                                 connectionstyle='arc3,rad=%s' % rad, shrinkA=0, shrinkB=0))


def label(ax, x, y, text, size=7.5, color=INK, ha='center', weight='normal', bg=True, style='normal'):
    kw = dict(bbox=dict(fc='white', ec='none', pad=1.2)) if bg else {}
    return ax.text(x, y, text, ha=ha, va='center', fontsize=size, color=color, weight=weight, style=style, **kw)


def check(fig, pairs, free=()):
    """Every boxed text lies inside its box with a margin; no two texts overlap."""
    fig.canvas.draw()
    r = fig.canvas.get_renderer()
    bbs = []
    for patch, txt in pairs:
        tb, pb = txt.get_window_extent(r), patch.get_window_extent(r)
        assert tb.x0 >= pb.x0 + 3 and tb.x1 <= pb.x1 - 3 and tb.y0 >= pb.y0 + 2 and tb.y1 <= pb.y1 - 2, \
            'text overflows box: %r' % txt.get_text()
        bbs.append((txt.get_text(), tb))
    for txt in free:
        bbs.append((txt.get_text(), txt.get_window_extent(r)))
    for i in range(len(bbs)):
        for j in range(i + 1, len(bbs)):
            assert not bbs[i][1].overlaps(bbs[j][1]), 'overlap: %r / %r' % (bbs[i][0], bbs[j][0])


def save(fig, path):
    fig.savefig(path, dpi=200, bbox_inches='tight', facecolor='white')
    plt.close(fig)
    print('ok', path)
