"""Figures 8.1 to 8.3. Run: python3 figures.py (Figure 8.2 reads captured-outputs/chapter-08/results.csv)"""
import csv, os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
from figlib import *

HERE = os.path.dirname(os.path.abspath(__file__))
RESULTS = os.path.join(HERE, '..', '..', 'captured-outputs', 'chapter-08', 'results.csv')


def fig_8_1():
    """Where time goes in a Fabric transaction."""
    fig, ax = canvas(6.6, 3.6, 13.2, 7.2)
    pairs, free = [], []
    stages = [
        ('1 Endorse', 'peers run the\nchaincode and\nsign the result', 'CPU: chaincode,\nsignatures, state\nreads'),
        ('2 Order', 'orderer checks the\nenvelope and waits\nto fill a batch', 'BatchTimeout,\nMaxMessageCount'),
        ('3 Agree', 'Raft leader\nreplicates the\nblock; fsync', 'disk latency,\nnetwork round\ntrips'),
        ('4 Validate', 'peer checks\nsignatures, policy\nand versions', 'CPU per\ntransaction;\nconflicts'),
        ('5 Commit', 'peer writes the\nblock and the\nstate database', 'disk; CouchDB\nslower than\nLevelDB'),
    ]
    for i, (t, d, lim) in enumerate(stages):
        x = 0.15 + i * 2.62
        pairs.append(box(ax, x, 5.6, 2.3, 0.9, B1, B1, t, size=7.5, color='white', weight='bold'))
        pairs.append(box(ax, x, 3.5, 2.3, 1.8, LIGHT, B1, d, size=6.4))
        pairs.append(box(ax, x, 1.4, 2.3, 1.5, 'white', MID, lim, size=6.2))
        if i:
            arrow(ax, (x - 0.32, 6.05), (x, 6.05))
    free.append(label(ax, 0.15, 3.18, 'what limits it:', size=6.4, ha='left', bg=False, style='italic'))
    ax.plot([0.15, 2.45], [0.95, 0.95], color=B2, lw=1.4)
    ax.plot([2.77, 12.85], [0.95, 0.95], color=B1, lw=1.4)
    free.append(label(ax, 1.3, 0.45, 'client: endorse', size=6.4, bg=False))
    free.append(label(ax, 7.8, 0.45, 'client: submit, then wait for the commit event', size=6.4, bg=False))
    check(fig, pairs, free)
    save(fig, os.path.join(HERE, 'Figure_8_1.png'))


def fig_8_2():
    """Measured throughput and latency against offered load for three batch settings."""
    rows = list(csv.DictReader(open(RESULTS)))
    labels = []
    for r in rows:
        if r['label'] not in labels:
            labels.append(r['label'])
    styles = {0: (B1, 'o', '-'), 1: (B2, 's', '--'), 2: ('#7F7F7F', '^', ':')}
    fig, (a1, a2) = plt.subplots(1, 2, figsize=(6.6, 2.9), dpi=200)
    for i, lab in enumerate(labels):
        rs = [r for r in rows if r['label'] == lab]
        x = [float(r['offered']) for r in rs]
        c, m, ls = styles[i]
        name = 'BatchTimeout %s, MaxMessageCount %s' % tuple(lab.split('/'))
        a1.plot(x, [float(r['tps']) for r in rs], color=c, marker=m, ls=ls, lw=1.2, ms=4, label=name)
        a2.plot(x, [float(r['p50']) / 1000 for r in rs], color=c, marker=m, ls=ls, lw=1.2, ms=4)
    top = max(float(r['offered']) for r in rows)
    a1.plot([0, top], [0, top], color=MID, lw=0.8, ls=(0, (2, 2)))
    a1.text(top * 0.52, top * 0.62, 'committed = offered', fontsize=6, color=MID, rotation=36)
    a1.set_xlabel('offered load (transactions per second)', fontsize=7)
    a1.set_ylabel('committed per second', fontsize=7)
    a2.set_xlabel('offered load (transactions per second)', fontsize=7)
    a2.set_ylabel('median latency (seconds, log scale)', fontsize=7)
    a2.set_yscale('log')
    a2.set_yticks([0.1, 0.2, 0.5, 1, 2, 5, 10, 20])
    a2.set_yticklabels(['0.1', '0.2', '0.5', '1', '2', '5', '10', '20'])
    a2.minorticks_off()
    for a in (a1, a2):
        a.tick_params(labelsize=6.5)
        a.grid(True, color=GREY, lw=0.6)
        for s in ('top', 'right'):
            a.spines[s].set_visible(False)
    fig.legend(loc='lower center', ncol=3, fontsize=6, frameon=False, bbox_to_anchor=(0.5, -0.02))
    fig.tight_layout(rect=(0, 0.08, 1, 1))
    save(fig, os.path.join(HERE, 'Figure_8_2.png'))


def fig_8_3():
    """Three interoperability patterns and whom each one trusts."""
    fig, ax = canvas(6.6, 3.7, 13.2, 7.4)
    pairs, free = [], []
    cols = [
        ('Notary', 'A named party or\ncommittee watches\nledger A and signs\nan attestation that\nledger B accepts',
         'Trust: the notaries'),
        ('Relay', 'A relay carries data\nand a proof from A;\nB\'s contract checks\nthe proof against\nA\'s endorsement\npolicy',
         'Trust: A\'s own\nendorsers'),
        ('Hash time lock', 'Both sides lock assets\nunder the hash of a\nsecret; revealing it\non one ledger lets\nthe other side claim;\ntimeouts refund',
         'Trust: no third party;\nboth must stay online'),
    ]
    for i, (t, d, trust) in enumerate(cols):
        x = 0.2 + i * 4.35
        pairs.append(frame(ax, x, 0.3, 4.05, 6.9, t))
        pairs.append(box(ax, x + 0.25, 5.2, 1.5, 0.9, LIGHT, B1, 'ledger A', size=6.6))
        pairs.append(box(ax, x + 2.3, 5.2, 1.5, 0.9, LIGHT, B1, 'ledger B', size=6.6))
        arrow(ax, (x + 1.75, 5.65), (x + 2.3, 5.65), style='<|-|>')
        pairs.append(box(ax, x + 0.25, 1.95, 3.55, 2.95, 'white', B2, d, size=6.2))
        pairs.append(box(ax, x + 0.25, 0.55, 3.55, 1.15, GREY, MID, trust, size=6.3, weight='bold'))
    check(fig, pairs, free)
    save(fig, os.path.join(HERE, 'Figure_8_3.png'))


if __name__ == '__main__':
    fig_8_1(); fig_8_3()
    if os.path.exists(RESULTS):
        fig_8_2()
