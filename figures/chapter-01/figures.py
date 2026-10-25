"""Figures 1.1 and 1.2. Run: python3 figures.py  (writes PNGs next to this file and checks geometry)."""
import os
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch

HERE = os.path.dirname(os.path.abspath(__file__))
B1, B2, LIGHT, GREY, INK = '#1F4E79', '#2E74B5', '#D9E2F1', '#F2F2F2', '#222222'
plt.rcParams['font.family'] = 'DejaVu Sans'


def box(ax, x, y, w, h, fc, ec, text, color=INK, size=9, weight='normal'):
    p = FancyBboxPatch((x, y), w, h, boxstyle='round,pad=0,rounding_size=0.08', fc=fc, ec=ec, lw=1.2)
    ax.add_patch(p)
    t = ax.text(x + w / 2, y + h / 2, text, ha='center', va='center', fontsize=size, color=color,
                weight=weight, wrap=False, linespacing=1.25)
    return p, t


def check(fig, ax, pairs, free_texts=()):
    """Every text inside its box with a margin; no two texts overlap."""
    fig.canvas.draw()
    r = fig.canvas.get_renderer()
    bbs = []
    for patch, txt in pairs:
        tb = txt.get_window_extent(r)
        pb = patch.get_window_extent(r)
        assert tb.x0 >= pb.x0 + 3 and tb.x1 <= pb.x1 - 3 and tb.y0 >= pb.y0 + 2 and tb.y1 <= pb.y1 - 2, \
            'text overflows box: %r' % txt.get_text()
        bbs.append((txt.get_text(), tb))
    for txt in free_texts:
        bbs.append((txt.get_text(), txt.get_window_extent(r)))
    for i in range(len(bbs)):
        for j in range(i + 1, len(bbs)):
            assert not bbs[i][1].overlaps(bbs[j][1]), 'overlap: %r / %r' % (bbs[i][0], bbs[j][0])


def fig_1_1():
    fig, ax = plt.subplots(figsize=(6.5, 3.0), dpi=200)
    fig.subplots_adjust(0, 0, 1, 1)
    ax.set_xlim(0, 13); ax.set_ylim(0, 6); ax.axis('off')
    cols = [
        ('Public\npermissionless', 'Anyone joins,\nreads and writes', 'Bitcoin,\nEthereum mainnet'),
        ('Public\npermissioned', 'Anyone reads,\napproved\nparties write', 'Open-read\nregistries'),
        ('Consortium\npermissioned', 'Known members\nshare governance', 'Fabric, Besu\n(QBFT), Corda'),
        ('Private\npermissioned', 'One organization\nruns all nodes', 'Internal\nledgers'),
        ('Distributed\ndatabase', 'One operator,\nmany replicas', 'Spanner,\nCockroachDB'),
        ('Centralized\ndatabase', 'One operator,\none system', 'A bank\'s core\nledger'),
    ]
    w, gap, x0 = 1.95, 0.16, 0.2
    pairs, free = [], []
    for i, (name, rule, ex) in enumerate(cols):
        x = x0 + i * (w + gap)
        home = i == 2
        pairs.append(box(ax, x, 3.05, w, 1.15, B1 if home else LIGHT, B1, name,
                         color='white' if home else INK, size=7.6, weight='bold'))
        pairs.append(box(ax, x, 1.75, w, 1.05, 'white', B2, rule, size=7.2))
        pairs.append(box(ax, x, 0.45, w, 1.05, GREY, '#999999', ex, size=7.2))
    # axis arrow above the boxes
    ax.add_patch(FancyArrowPatch((x0, 4.75), (x0 + 6 * w + 5 * gap, 4.75), arrowstyle='<|-|>',
                                 mutation_scale=12, lw=1.4, color=B2))
    free.append(ax.text(x0, 5.3, 'Less trust needed in any one operator', ha='left', va='center', fontsize=8, color=B1))
    free.append(ax.text(x0 + 6 * w + 5 * gap, 5.3, 'Simpler to run, faster, one party in control',
                        ha='right', va='center', fontsize=8, color=B1))
    check(fig, ax, pairs, free)
    out = os.path.join(HERE, 'Figure_1_1.png')
    fig.savefig(out, dpi=200, bbox_inches='tight', facecolor='white')
    plt.close(fig)
    return out


def fig_1_2():
    fig, ax = plt.subplots(figsize=(6.5, 4.6), dpi=200)
    fig.subplots_adjust(0, 0, 1, 1)
    ax.set_xlim(0, 13); ax.set_ylim(0, 9.4); ax.axis('off')
    rows = [
        ('Known participants', 'X.509 identities from each\norganization\'s CA, checked by MSPs', 'Ch. 2, 5'),
        ('Confidentiality', 'Channels and private\ndata collections', 'Ch. 2, 7'),
        ('Predictable performance\nand final settlement', 'Execute-order-validate;\nRaft or SmartBFT ordering, no forks', 'Ch. 2, 4, 8'),
        ('Governance and\nchange control', 'Channel policies; chaincode\nlifecycle approvals by members', 'Ch. 3, 5'),
        ('Regulatory compliance\nand audit', 'Signed transactions, key history,\nprivate data purge, HSM support', 'Ch. 7'),
    ]
    pairs, free = [], []
    free.append(ax.text(1.9, 9.0, 'Enterprise requirement', ha='center', fontsize=8.5, weight='bold', color=B1))
    free.append(ax.text(7.15, 9.0, 'What Fabric provides', ha='center', fontsize=8.5, weight='bold', color=B1))
    free.append(ax.text(11.85, 9.0, 'Where in this book', ha='center', fontsize=8.5, weight='bold', color=B1))
    h, step = 1.25, 1.7
    for i, (req, mech, ch) in enumerate(rows):
        y = 7.15 - i * step
        pairs.append(box(ax, 0.1, y, 3.6, h, LIGHT, B1, req, size=8, weight='bold'))
        pairs.append(box(ax, 4.7, y, 4.9, h, 'white', B2, mech, size=7.8))
        pairs.append(box(ax, 10.8, y, 2.1, h, GREY, '#999999', ch, size=8.5))
        for xa, xb in ((3.7, 4.7), (9.6, 10.8)):
            ax.add_patch(FancyArrowPatch((xa + 0.05, y + h / 2), (xb - 0.05, y + h / 2), arrowstyle='-|>',
                                         mutation_scale=11, lw=1.2, color=B2))
    check(fig, ax, pairs, free)
    out = os.path.join(HERE, 'Figure_1_2.png')
    fig.savefig(out, dpi=200, bbox_inches='tight', facecolor='white')
    plt.close(fig)
    return out


if __name__ == '__main__':
    for f in (fig_1_1(), fig_1_2()):
        print('ok', f)
