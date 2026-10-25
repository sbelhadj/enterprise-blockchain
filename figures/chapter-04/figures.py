"""Figures 4.1 to 4.4. Run: python3 figures.py"""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
from figlib import *

HERE = os.path.dirname(os.path.abspath(__file__))


def fig_4_1():
    """What the ordering service decides, and what it never sees."""
    fig, ax = canvas(6.5, 2.9, 13, 5.8)
    pairs, free = [], []
    pairs.append(box(ax, 0.1, 2.0, 2.6, 1.6, LIGHT, B1, 'Endorsing\npeers\n(execute)', size=7.5, weight='bold'))
    pairs.append(box(ax, 3.4, 1.4, 5.3, 2.8, B1, B1, 'Ordering service\n\nDecides: which transactions,\nin which order, in which block',
                     size=7.8, color='white', weight='bold'))
    pairs.append(box(ax, 9.4, 2.0, 3.5, 1.6, LIGHT, B1, 'Every peer\n(validate, commit)', size=7.5, weight='bold'))
    arrow(ax, (2.7, 2.8), (3.4, 2.8))
    arrow(ax, (8.7, 2.8), (9.4, 2.8))
    free.append(label(ax, 6.05, 0.75, 'Never checks: endorsement policies, read-write versions, business rules', size=7,
                      color=INK, bg=False, style='italic'))
    free.append(label(ax, 6.05, 0.3, 'Can still: drop, delay or reorder transactions it receives', size=7,
                      color=INK, bg=False, style='italic'))
    check(fig, pairs, free)
    save(fig, os.path.join(HERE, 'Figure_4_1.png'))


def fig_4_2():
    """Raft roles and the transitions between them."""
    fig, ax = canvas(6.5, 2.8, 13, 5.6)
    pairs, free = [], []
    pairs.append(box(ax, 0.3, 2.0, 3.0, 1.5, LIGHT, B1, 'Follower', size=9, weight='bold'))
    pairs.append(box(ax, 5.0, 2.0, 3.0, 1.5, LIGHT, B1, 'Candidate', size=9, weight='bold'))
    pairs.append(box(ax, 9.7, 2.0, 3.0, 1.5, B1, B1, 'Leader', size=9, weight='bold', color='white'))
    arrow(ax, (3.3, 3.1), (5.0, 3.1))
    free.append(label(ax, 4.15, 4.0, 'no heartbeat for\nElectionTick ticks:\nnew term, vote for self', size=6.5, bg=False))
    arrow(ax, (8.0, 3.1), (9.7, 3.1))
    free.append(label(ax, 8.85, 4.0, 'votes from\na majority', size=6.5, bg=False))
    arrow(ax, (5.0, 2.4), (3.3, 2.4))
    free.append(label(ax, 4.15, 1.55, 'another leader\nor higher term', size=6.5, bg=False))
    arrow(ax, (11.2, 2.0), (1.8, 2.0), rad=-0.25)
    free.append(label(ax, 6.5, 0.45, 'sees a higher term: steps down to follower', size=6.5, bg=False))
    free.append(label(ax, 6.5, 1.5, 'split vote: the candidate\nstarts a new term', size=6.5, bg=False))
    check(fig, pairs, free)
    save(fig, os.path.join(HERE, 'Figure_4_2.png'))


def fig_4_3():
    """Raft log replication and commit."""
    fig, ax = canvas(6.5, 3.0, 13, 6)
    pairs, free = [], []
    x0 = {'Leader': 0.3, 'Follower A': 4.6, 'Follower B': 8.9}
    for name, x in x0.items():
        free.append(label(ax, x + 1.9, 5.6, name, size=8, weight='bold', color=B1, bg=False))
        entries = ['block 5', 'block 6', 'block 7'] if name != 'Follower B' else ['block 5', 'block 6', '']
        for i, e in enumerate(entries):
            fc = LIGHT if e and (i < 2 or name != 'Follower B') else 'white'
            if e == '':
                pairs.append(box(ax, x + 0.2 + i * 1.25, 3.9, 1.1, 1.0, 'white', MID, '...', size=7, ls='--'))
            else:
                pairs.append(box(ax, x + 0.2 + i * 1.25, 3.9, 1.1, 1.0, fc, B1, e.replace(' ', '\n'), size=6.8))
    arrow(ax, (4.2, 4.4), (4.75, 4.4))
    arrow(ax, (8.5, 4.4), (9.05, 4.4), ls='--')
    steps = ['1. The leader appends block 7 to its log and sends it to every follower.',
             '2. Follower A writes it to its write-ahead log and acknowledges. Follower B is slow.',
             '3. Leader plus Follower A is a majority (2 of 3): block 7 is committed.',
             '4. The leader tells the followers; each node writes block 7 to its block store.',
             '5. Follower B catches up later from the leader. Nothing waits for it.']
    for i, s in enumerate(steps):
        free.append(label(ax, 0.3, 3.1 - i * 0.62, s, size=7, ha='left', bg=False))
    check(fig, pairs, free)
    save(fig, os.path.join(HERE, 'Figure_4_3.png'))


def fig_4_4():
    """SmartBFT: three-phase agreement among four nodes."""
    fig, ax = canvas(6.5, 3.6, 13, 7.2)
    pairs, free = [], []
    nodes = ['Leader (node 1)', 'Node 2', 'Node 3', 'Node 4 (faulty)']
    ys = [6.0, 4.7, 3.4, 2.1]
    for n, y in zip(nodes, ys):
        pairs.append(box(ax, 0.1, y - 0.4, 2.4, 0.8, LIGHT if 'faulty' not in n else 'white', B1, n, size=7,
                         weight='bold', ls='-' if 'faulty' not in n else '--'))
        ax.plot([2.5, 12.8], [y, y], color=MID, lw=0.8, ls=(0, (4, 3)), zorder=0.5)
    phases = [(3.0, 5.6, 'pre-prepare:\nleader proposes\nthe block'), (5.9, 8.5, 'prepare: each node\nconfirms it saw\nthe same proposal'),
              (8.8, 11.4, 'commit: each node\nsigns; 2f+1 = 3\nsignatures decide')]
    for x0_, x1, text in phases:
        free.append(label(ax, (x0_ + x1) / 2, 0.85, text, size=6.6, bg=False))
    # pre-prepare: leader to others
    for y in ys[1:]:
        arrow(ax, (3.0, ys[0]), (5.6, y), lw=1.0)
    # prepare and commit: all-to-all among nodes 1-3 (sketched)
    for (a, b) in [(5.9, 8.5), (8.8, 11.4)]:
        for y0 in ys[:3]:
            for y1 in ys[:3]:
                if y0 != y1:
                    arrow(ax, (a, y0), (b, y1), lw=0.7, color=B2)
    pairs.append(box(ax, 11.6, 3.2, 1.3, 3.2, B1, B1, 'block\nwritten\nwith 3\nsigna-\ntures', size=6.5, color='white'))
    free.append(label(ax, 7.2, 1.75, 'node 4 is silent or lies; the other three still reach 2f + 1', size=6.5, bg=False, style='italic'))
    check(fig, pairs, free)
    save(fig, os.path.join(HERE, 'Figure_4_4.png'))


if __name__ == '__main__':
    fig_4_1(); fig_4_2(); fig_4_3(); fig_4_4()
