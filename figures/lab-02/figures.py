"""Figure L2.1. Run: python3 figures.py"""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
from figlib import *

HERE = os.path.dirname(os.path.abspath(__file__))


def fig_l2_1():
    """PharmaTrace batch states, and whose peers endorse each change."""
    fig, ax = canvas(6.6, 4.1, 13.2, 8.2)
    pairs, free = [], []
    states = [('PRODUCED', 'holder:\nManufacturer'), ('SHIPPED', 'to:\nDistributor'),
              ('RECEIVED', 'holder:\nDistributor'), ('SHIPPED', 'to:\nPharmacy'),
              ('RECEIVED', 'holder:\nPharmacy'), ('DISPENSED', 'all units\ndispensed')]
    w, gap = 1.8, 0.4
    for i, (s, d) in enumerate(states):
        x = 0.2 + i * (w + gap)
        pairs.append(box(ax, x, 6.4, w, 0.8, B1, B1, s, size=6.6, color='white',
                         weight='bold'))
        pairs.append(box(ax, x, 5.2, w, 1.0, LIGHT, B1, d, size=6.0))
        if i:
            arrow(ax, (x - gap, 6.8), (x, 6.8))
            free.append(label(ax, x - gap / 2, 7.45, str(i + 1) if i < 5 else 'D', size=6.5, bg=False,
                              weight='bold'))
    free.append(label(ax, 1.1, 7.75, '1', size=6.5, bg=False, weight='bold'))
    pairs.append(box(ax, 4.6, 3.3, 4.0, 0.8, 'white', B1, 'RECALLED', size=6.8,
                     weight='bold'))
    for i in range(6):
        x = 0.2 + i * (w + gap) + w / 2
        arrow(ax, (x, 5.2), (6.6, 4.1), color=MID, ls='--', lw=0.8)
    free.append(label(ax, 10.6, 3.7, '6  from any state', size=6.3, bg=False))
    legend = ('1  ProduceBatch: Manufacturer calls; Manufacturer and Regulator peers endorse\n'
              '2, 4  ShipBatch: the holder calls; the holder\'s peer endorses\n'
              '3, 5  ReceiveBatch: the receiver calls; holder and receiver peers endorse\n'
              'D  DispenseUnit, once per unit: the Pharmacy calls and endorses\n'
              '6  RecallBatch: Regulator or Manufacturer calls; the holder\'s peer endorses')
    pairs.append(box(ax, 0.2, 0.9, 12.8, 1.9, GREY, MID, legend, size=6.3, ha='left'))
    check(fig, pairs, free)
    save(fig, os.path.join(HERE, 'Figure_L2_1.png'))


if __name__ == '__main__':
    fig_l2_1()
