#!/usr/bin/env python3
import argparse
import html
import re
from collections import OrderedDict
from pathlib import Path


NODE_RE = re.compile(r'^\s*([\-0-9]+) \[label="(.*)"(?:,style = filled)?\]\s*$')
EDGE_RE = re.compile(r'^\s*([\-0-9]+) -> ([\-0-9]+) \[label="([^"]+)".*\]\s*;\s*$')


def unescape_label(text: str) -> str:
    return text.replace(r'\n', chr(10)).replace(r'\"', '"').replace(r'\\', chr(92))


def parse_state(label: str) -> dict:
    data = {}
    for raw_line in unescape_label(label).splitlines():
        line = raw_line.strip()
        if not line.startswith('/\\ '):
            continue
        body = line[3:]
        if ' = ' not in body:
            continue
        key, value = body.split(' = ', 1)
        data[key.strip()] = value.strip()
    return data


def summarize_stack(stack_value: str) -> str:
    if stack_value == '<<>>':
        return '[]'
    frames = re.findall(r'\[menu \|-> "([^"]+)", selected \|-> "([^"]+)"\]', stack_value)
    return ' -> '.join(f'{menu}:{selected}' for menu, selected in frames) if frames else stack_value


def abstract_state(data: dict) -> str:
    open_value = data.get('open', 'FALSE')
    active_top = data.get('activeTop', '"?"').strip('"')
    stack_text = summarize_stack(data.get('stack', '<<>>'))
    if open_value == 'FALSE':
        return f'closed\nactiveTop={active_top}'
    return f'open\nactiveTop={active_top}\nstack={stack_text}'


def event_label(edge_label: str, target_state: dict) -> str:
    event_state = target_state.get('lastEvent', '')
    kind_match = re.search(r'kind \|-> "([^"]+)"', event_state)
    target_match = re.search(r'target \|-> "([^"]+)"', event_state)
    level_match = re.search(r'level \|-> ([0-9]+)', event_state)
    kind = kind_match.group(1) if kind_match else edge_label
    target = target_match.group(1) if target_match else None
    level = level_match.group(1) if level_match else None

    if kind in {'Hover', 'Click'} and target:
        return f'{kind}({target}@L{level})' if level else f'{kind}({target})'
    if kind in {'HoverTop', 'ClickTop'} and target:
        return f'{kind}({target})'
    if kind == 'ActivateSelected' and target:
        return f'ActivateSelected({target})'
    return kind


def color_for(label: str) -> str:
    if label.startswith('Hover'):
        return '#4c78a8'
    if label.startswith('ClickTop') or label.startswith('HoverTop'):
        return '#f58518'
    if label.startswith('Click('):
        return '#54a24b'
    if label.startswith('ActivateSelected'):
        return '#b279a2'
    if label.startswith('GoBack') or label.startswith('ClickOutside'):
        return '#e45756'
    if label.startswith('OpenRoot'):
        return '#72b7b2'
    return '#666666'


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('input_dot')
    parser.add_argument('output_dot')
    args = parser.parse_args()

    input_path = Path(args.input_dot)
    output_path = Path(args.output_dot)

    nodes = {}
    edges = []

    for line in input_path.read_text().splitlines():
        node_match = NODE_RE.match(line.rstrip(';'))
        if node_match:
            node_id, label = node_match.groups()
            nodes[node_id] = parse_state(label)
            continue
        edge_match = EDGE_RE.match(line)
        if edge_match:
            edges.append(edge_match.groups())

    abstract_nodes = OrderedDict()
    abstract_edges = OrderedDict()

    for node_id, state in nodes.items():
        abstract_nodes[node_id] = abstract_state(state)

    for src, dst, edge_label in edges:
        src_label = abstract_nodes.get(src)
        dst_label = abstract_nodes.get(dst)
        if src_label is None or dst_label is None:
            continue
        compact_label = event_label(edge_label, nodes[dst])
        key = (src_label, dst_label, compact_label)
        abstract_edges[key] = color_for(compact_label)

    state_ids = OrderedDict()
    for src_label, dst_label, _ in abstract_edges.keys():
        state_ids.setdefault(src_label, f's{len(state_ids)}')
        state_ids.setdefault(dst_label, f's{len(state_ids)}')

    lines = [
        'strict digraph CompactGraph {',
        'rankdir=LR;',
        'graph [overlap=false, splines=true, fontname="Helvetica"];',
        'node [shape=box, style="rounded,filled", fillcolor="#f8f8f8", color="#cccccc", fontname="Helvetica"];',
        'edge [fontname="Helvetica"];',
    ]

    for state_label, state_id in state_ids.items():
        safe = html.escape(state_label).replace('\n', '<BR ALIGN="LEFT"/>')
        lines.append(f'{state_id} [label=<{safe}>];')

    for (src_label, dst_label, compact_label), color in abstract_edges.items():
        src_id = state_ids[src_label]
        dst_id = state_ids[dst_label]
        safe_label = html.escape(compact_label)
        lines.append(
            f'{src_id} -> {dst_id} [label="{safe_label}", color="{color}", fontcolor="{color}"];'
        )

    lines.append('}')
    output_path.write_text('\n'.join(lines) + '\n')


if __name__ == '__main__':
    main()
