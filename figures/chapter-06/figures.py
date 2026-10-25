"""Figures 6.1 and 6.2. Run: python3 figures.py"""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
from figlib import *
from matplotlib.patches import Rectangle

HERE = os.path.dirname(os.path.abspath(__file__))


def fig_6_1():
    """The evaluation framework: four lenses and the evidence behind them."""
    fig, ax = canvas(6.6, 3.7, 13.2, 7.4)
    pairs, free = [], []
    lenses = [
        ('Structural', 'Is there a multi-party\nproblem? Is there an\nanchor buyer or a\nregulatory mandate?'),
        ('Governance', 'Who decides, who\noperates the nodes, who\nmay leave, and what\nhappens if they do?'),
        ('Technical', 'Platform, channels,\nprivacy, endorsement,\nintegration with the\nsystems people use'),
        ('Commercial', 'Who pays, who gains,\nhow fast adoption must\ncome for the funding\nto last'),
    ]
    for i, (t, d) in enumerate(lenses):
        x = 0.2 + i * 3.25
        pairs.append(box(ax, x, 5.6, 3.0, 1.0, B1, B1, t, size=8, color='white', weight='bold'))
        pairs.append(box(ax, x, 3.0, 3.0, 2.4, LIGHT, B1, d, size=6.6))
    pairs.append(box(ax, 0.2, 0.3, 12.8, 1.9, GREY, MID,
                     'Evidence for every answer, graded: primary (the operator, a regulator, a filing),\n'
                     'secondary (independent trade press, research), promotional (vendor case studies,\n'
                     'launch announcements). Dated facts over adjectives; outcomes over launches.', size=6.8))
    for i in range(4):
        arrow(ax, (1.7 + i * 3.25, 3.0), (1.7 + i * 3.25, 2.2), color=MID)
    check(fig, pairs, free)
    save(fig, os.path.join(HERE, 'Figure_6_1.png'))


def fig_6_2():
    """Timeline of the Chapter 6 cases, launch to outcome."""
    cases = [  # name, platform, start, end, status
        ('we.trade', 'Fabric', 2017, 2022.45, 'closed'),
        ('Contour', 'Corda', 2017, 2023.9, 'closed'),
        ('Marco Polo', 'Corda', 2016, 2023.2, 'closed'),
        ('Komgo', 'Quorum', 2018, 2025.85, 'operating, Nov 2025'),
        ('TradeLens', 'Fabric', 2018, 2023.25, 'closed'),
        ('IBM Food Trust', 'Fabric', 2018.77, 2024.5, 'reported 2024'),
        ('DL Freight', 'Fabric', 2019, 2020.8, 'reported 2020'),
        ('Change Healthcare', 'Fabric', 2018, 2019.5, 'reported 2019'),
        ('Avaneer Health', 'Fabric', 2021.45, 2022.25, 'reported 2022'),
        ('MediLedger pilot', 'not named', 2019, 2020.25, 'pilot ended'),
        ('GoDirect Trade', 'Fabric', 2019, 2019.87, 'reported 2019'),
        ('Circulor', 'Fabric', 2018, 2023.7, 'reported 2023'),
        ('Everledger', 'not named', 2015, 2023.3, 'administration'),
    ]
    fig, ax = canvas(6.6, 4.6, 13.2, 9.2)
    x0, x1, y0 = 3.3, 12.9, 8.6
    sx = lambda yr: x0 + (yr - 2015) / (2027 - 2015) * (x1 - x0)
    free = []
    for yr in range(2015, 2028, 2):
        ax.plot([sx(yr), sx(yr)], [0.5, y0 + 0.1], color='#DDDDDD', lw=0.6, zorder=0)
        free.append(label(ax, sx(yr), 0.25, str(yr), size=6.3, bg=False, color=MID))
    for i, (n, p, a, b, st) in enumerate(cases):
        y = y0 - i * 0.62
        free.append(label(ax, 0.1, y, '%s (%s)' % (n, p), size=6.2, ha='left', bg=False))
        closed = st in ('closed', 'administration')
        col = MID if closed else B2
        ax.add_patch(Rectangle((sx(a), y - 0.14), sx(b) - sx(a), 0.28, fc=col, ec='none'))
        free.append(label(ax, sx(b) + 0.1, y, st, size=5.8, ha='left', bg=False,
                          color=INK if closed else B1, style='italic'))
    check(fig, [], free)
    save(fig, os.path.join(HERE, 'Figure_6_2.png'))


if __name__ == '__main__':
    fig_6_1(); fig_6_2()
