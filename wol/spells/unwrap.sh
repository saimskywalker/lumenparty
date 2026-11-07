#!/usr/bin/env bash
# Unwrap — reads a shell command on stdin and prints every simple command
# that would run, one per line, as "<queued><TAB><words>":
#   queued  1 when it runs inside the Slow queue (lumenparty slow '...'), else 0
#   words   the command's words with shell quoting removed (Perl's
#           Text::ParseWords), joined by one space; whitespace inside a word
#           becomes \x1f, so a quoted message never looks like a command
# It splits on ; && || | & newlines, ( ) { } if/then/while/do and !; reads
# into sh|bash|zsh -c, eval, $(...), backticks, <(...), here-docs,
# here-strings and literal pipes into a shell or an interpreter, one-liners
# (python -c, perl -e, node -e, awk ...), find -exec, the Slow wrapper and
# git aliases; and removes prefixes (env, sudo, nice, nohup, timeout, xargs,
# command, exec, time ...) and git's global options. A runner prefix
# (bundle exec, npx, fvm, dart run ...) adds a second line without it.
# A line "!<TAB>..." means "too deeply nested to check".
# A guard rail, not a full shell: a script file, a shell alias or a binary on
# PATH stays out of sight.
exec perl -x "$0" "$@"
: <<'PERL'
#!perl
use strict;
use warnings;
use Text::ParseWords qw(shellwords);
open STDERR, '>', '/dev/null';

my $MAXDEPTH = 10;
my $MAXWORK = 400;
my ($work, @out, %line_alias) = (0);
my %SHELL = map { $_ => 1 } qw(sh bash zsh dash ksh mksh ash yash fish);
my $INTERP = qr/^(?:python[0-9.]*|pypy[0-9.]*|perl[0-9.]*|node|nodejs|ruby|deno|bun|php|osascript|awk|gawk|mawk|nawk|lua|luajit|Rscript|tclsh|groovy)$/;
my %RESERVED = map { $_ => 1 } ('!', '{', '}', 'if', 'then', 'elif', 'else', 'do', 'while', 'until', 'coproc');
my %GIT_BUILTIN = map { $_ => 1 } qw(add am apply archive bisect blame branch bundle cat-file check-ignore
  checkout cherry cherry-pick clean clone commit config describe diff difftool fetch for-each-ref
  format-patch fsck gc grep help init log ls-files ls-remote ls-tree merge merge-base mergetool mv notes
  pull push range-diff rebase reflog remote repack reset restore rev-list rev-parse revert rm send-pack
  shortlog show show-ref sparse-checkout stash status submodule switch symbolic-ref tag update-ref var
  version worktree);

sub base { my $x = shift; $x =~ s{.*/(?=.)}{}; return $x; }
sub sq { my $s = shift; $s =~ s/'/'\\''/g; return "'$s'"; }
sub ansi {
  my $s = shift;
  my %e = (a => "\a", b => "\b", e => "\e", f => "\f", n => "\n", r => "\r", t => "\t", v => "\x0b");
  $s =~ s/\\(?:([abefnrtv])|x([0-9A-Fa-f]{1,2})|([0-7]{1,3})|(.))/
    defined $1 ? $e{$1} : defined $2 ? chr(hex $2) : defined $3 ? chr(oct $3) : $4/gse;
  return $s;
}

sub emit {
  my ($q, @w) = @_;
  return unless @w;
  my @x = map { my $y = $_; $y =~ s/\s/\x1f/g; $y } @w;
  push @out, "$q\t" . join(' ', @x);
  my $b = base($x[0]);
  push @out, "$q\t" . join(' ', $b, @x[1 .. $#x]) if $b ne $x[0];
}

sub words_of {
  my ($t) = @_;
  return () unless defined $t && $t =~ /\S/;
  # In double quotes the shell keeps a backslash unless it escapes $ ` " \;
  # shellwords would drop it, so double it first.
  $t =~ s/(\\.|'[^']*')|("(?:[^"\\]|\\.)*")/defined $1 ? $1 : do { my $x = $2; $x =~ s{\\([^\$`"\\])}{\\\\$1}g; $x }/gse;
  my @w = shellwords($t);
  @w = split ' ', $t unless @w;
  my @x;
  for my $w (@w) {    # one level of brace expansion: a{b,c} -> ab ac
    if ($w !~ /\$\{/ && $w =~ /^(.*?)\{([^{}]*,[^{}]*)\}(.*)$/s) {
      my ($pre, $mid, $post) = ($1, $2, $3);
      push @x, map { "$pre$_$post" } split /,/, $mid, -1;
    } else { push @x, $w }
  }
  return @x;
}

# Index of the ")" that closes the "(" just before $i, or -1.
sub find_close {
  my ($s, $i) = @_;
  my ($depth, $n) = (1, length $s);
  while ($i < $n) {
    my $c = substr($s, $i, 1);
    if ($c eq '\\') { $i += 2; next }
    if ($c eq "'") { my $e = index($s, "'", $i + 1); return -1 if $e < 0; $i = $e + 1; next }
    if ($c eq '`') { my $e = index($s, '`', $i + 1); return -1 if $e < 0; $i = $e + 1; next }
    if ($c eq '"') {
      $i++;
      while ($i < $n) {
        my $d = substr($s, $i, 1);
        if ($d eq '\\') { $i += 2; next }
        last if $d eq '"';
        if ($d eq '$' && substr($s, $i + 1, 1) eq '(') { my $e = find_close($s, $i + 2); return -1 if $e < 0; $i = $e + 1; next }
        $i++;
      }
      $i++; next;
    }
    if ($c eq '(') { $depth++ }
    elsif ($c eq ')') { return $i if --$depth == 0 }
    $i++;
  }
  return -1;
}

# What an echo / printf / cat <<EOF of literal words prints, or undef.
sub literal_of_seg {
  my ($sg) = @_;
  return undef unless $sg;
  my @w = words_of($sg->{text});
  return undef unless @w;
  my $c = base(shift @w);
  return undef if grep { /[\$`]/ } @w;
  if ($c eq 'echo') { shift @w while @w && $w[0] =~ /^-[neE]+$/; return ansi(join(' ', @w)) . "\n" }
  if ($c eq 'printf') {
    my $fmt = shift(@w) // '';
    my ($o, $loops) = ('', 0);
    do {
      (my $f = $fmt) =~ s/%(?:%|[-+ #0-9.]*([sbdiouxXcq]))/defined $1 ? (shift(@w) \/\/ '') : '%'/ge;
      $o .= $f;
    } while (@w && $fmt =~ /%[^%]/ && ++$loops < 50);
    return ansi($o);
  }
  if ($c eq 'cat') {
    my @here = @{ $sg->{here} };
    my @rest = grep { $_ ne '<<HEREDOC' } @w;
    return join('', @here) if @here && !@rest;
    return $1 if @rest && $rest[0] =~ /^<<<(.+)$/s;
    return $rest[1] if @rest == 2 && $rest[0] eq '<<<';
  }
  return undef;
}

sub literal_of_text {
  my ($t, $d) = @_;
  my @segs = grep { $_->{text} =~ /\S/ } scan($t, 0, $d, 1);
  return @segs == 1 ? literal_of_seg($segs[0]) : undef;
}

# Split a command text into segments {text, sep, here}; command
# substitutions are analysed (unless $quiet) and replaced by their literal
# output when they only print literals, else by the word "$(...)".
sub scan {
  my ($s, $q, $d, $quiet) = @_;
  my @segs;
  my $seg = { text => '', sep => '', here => [] };
  my @pend;
  my ($sq, $dq, $i, $n) = (0, 0, 0, length $s);
  my $cut = sub { push @segs, $seg; $seg = { text => '', sep => $_[0], here => [] } };
  my $subst = sub {
    my ($inner, $in_dq) = @_;
    analyze($inner, $q, $d + 1) unless $quiet;
    my $lit = literal_of_text($inner, $d + 1);
    return '$(...)' unless defined $lit;
    $lit =~ s/\n+$//;
    if ($in_dq) { $lit =~ s/([\\"\$`])/\\$1/g } else { $lit =~ s/([^\w\s\/.,:=+\-@%^])/\\$1/g }
    return $lit;
  };
  while ($i < $n) {
    my $c = substr($s, $i, 1);
    if ($sq) { $seg->{text} .= $c; $sq = 0 if $c eq "'"; $i++; next }
    if ($c eq '\\') { $seg->{text} .= substr($s, $i, 2); $i += 2; next }
    if ($c eq '$' && substr($s, $i + 1, 1) eq '(') {
      my $e = find_close($s, $i + 2);
      if ($e < 0) { $seg->{text} .= substr($s, $i); last }
      if (substr($s, $i + 2, 1) eq '(') { $seg->{text} .= substr($s, $i, $e - $i + 1); $i = $e + 1; next }
      $seg->{text} .= $subst->(substr($s, $i + 2, $e - $i - 2), $dq);
      $i = $e + 1; next;
    }
    if ($c eq '`') {
      my $e = index($s, '`', $i + 1);
      if ($e < 0) { $seg->{text} .= substr($s, $i); last }
      (my $inner = substr($s, $i + 1, $e - $i - 1)) =~ s/\\([\\`\$])/$1/g;
      $seg->{text} .= $subst->($inner, $dq);
      $i = $e + 1; next;
    }
    if ($dq) { $seg->{text} .= $c; $dq = 0 if $c eq '"'; $i++; next }
    if ($c eq "'") { $sq = 1; $seg->{text} .= $c; $i++; next }
    if ($c eq '"') { $dq = 1; $seg->{text} .= $c; $i++; next }
    if (($c eq '<' || $c eq '>') && substr($s, $i + 1, 1) eq '(') {
      my $e = find_close($s, $i + 2);
      if ($e < 0) { $seg->{text} .= substr($s, $i); last }
      analyze(substr($s, $i + 2, $e - $i - 2), $q, $d + 1) unless $quiet;
      $seg->{text} .= '/dev/fd/63'; $i = $e + 1; next;
    }
    if ($c eq '#' && ($seg->{text} eq '' || $seg->{text} =~ /\s$/)) {
      my $e = index($s, "\n", $i); $i = $e < 0 ? $n : $e; next;
    }
    if (substr($s, $i, 3) eq '<<<') { $seg->{text} .= '<<<'; $i += 3; next }
    if (substr($s, $i, 2) eq '<<' && substr($s, $i + 2) =~ /^(-?)[ \t]*(?:'([^'\n]*)'|"([^"\n]*)"|\\?([^\s;&|<>()]+))/) {
      push @pend, [$seg, defined $2 ? $2 : defined $3 ? $3 : $4, $1 eq '-'];
      $seg->{text} .= ' <<HEREDOC '; $i += 2 + length $&; next;
    }
    if ($c eq "\n") {
      $i++;
      for my $p (@pend) {
        my ($owner, $tag, $tabs, $body) = (@$p, '');
        while ($i < $n) {
          my $e = index($s, "\n", $i);
          my $line = $e < 0 ? substr($s, $i) : substr($s, $i, $e - $i);
          $i = $e < 0 ? $n : $e + 1;
          $line =~ s/^\t+// if $tabs;
          last if $line eq $tag;
          $body .= "$line\n";
        }
        push @{ $owner->{here} }, $body;
      }
      @pend = ();
      $cut->("\n"); next;
    }
    if ($c eq ';') { $i++; $i++ if substr($s, $i, 1) =~ /^[;&]$/; $cut->(';'); next }
    if ($c eq '&') {
      my $nx = substr($s, $i + 1, 1);
      if ($nx eq '&') { $cut->('&&'); $i += 2; next }
      if ($nx eq '>' || $seg->{text} =~ /[<>]$/) { $seg->{text} .= '&'; $i++; next }
      $cut->('&'); $i++; next;
    }
    if ($c eq '|') {
      my $nx = substr($s, $i + 1, 1);
      if ($nx eq '|') { $cut->('||'); $i += 2; next }
      if ($seg->{text} =~ />$/) { $seg->{text} .= '|'; $i++; next }
      $cut->('|'); $i += $nx eq '&' ? 2 : 1; next;
    }
    if ($c eq '(' && $seg->{text} =~ /(?:^|\s)[A-Za-z_][A-Za-z0-9_]*\+?=$/) {
      my $e = find_close($s, $i + 1);
      if ($e < 0) { $seg->{text} .= substr($s, $i); last }
      $seg->{text} .= substr($s, $i, $e - $i + 1); $i = $e + 1; next;
    }
    if ($c eq '(' || $c eq ')') { $cut->($c); $i++; next }
    $seg->{text} .= $c; $i++;
  }
  push @segs, $seg;
  return @segs;
}

sub analyze {
  my ($text, $q, $d) = @_;
  return unless defined $text;
  if ($d > $MAXDEPTH || ++$work > $MAXWORK) { push @out, "!\ttoo deep"; return }
  $text =~ s/\\\n//g;
  $text =~ s/\$'((?:\\.|[^'\\])*)'/sq(ansi($1))/ge;
  my $prev;
  for my $sg (scan($text, $q, $d, 0)) {
    my @w = words_of($sg->{text});
    my $stdin = @{ $sg->{here} } ? join('', @{ $sg->{here} }) : undef;
    for my $k (0 .. $#w) {
      $stdin = length $1 ? $1 : $w[$k + 1] if $w[$k] =~ /^\d*<<<(.*)$/s;
    }
    $stdin = literal_of_seg($prev) if !defined $stdin && $sg->{sep} eq '|';
    command($q, $d, $stdin, @w) if @w;
    $prev = $sg;
  }
}

sub git_alias {
  my ($sub, $dir) = @_;
  return undef unless $sub =~ /^[A-Za-z0-9][A-Za-z0-9._-]*$/;
  my @cmd = ('git');
  push @cmd, '-C', $dir if defined $dir;
  open(my $fh, '-|', @cmd, 'config', '--get', "alias.$sub") or return undef;
  my $v = do { local $/; <$fh> };
  close $fh;
  return undef unless defined $v && length $v;
  chomp $v;
  return $v;
}

# String literals of a one-line program, each analysed as a command, and
# runs of literals ("git", "push", ...) joined into one.
sub code {
  my ($q, $d, $src) = @_;
  return unless defined $src;
  my (@lits, @runs);
  while ($src =~ /("""|''')(.*?)\1|(["'`])((?:\\.|(?!\3).)*)\3/gs) {
    my $l = defined $2 ? $2 : $4;
    $l =~ s/\\(["'\\`])/$1/g;
    $l =~ s/\\n/\n/g;
    push @lits, [$l, $-[0], $+[0]];
  }
  for my $k (0 .. $#lits) {
    analyze($lits[$k][0], $q, $d + 1);
    my $gap = $k ? substr($src, $lits[$k - 1][2], $lits[$k][1] - $lits[$k - 1][2]) : 'x';
    if ($gap =~ /^[\s,\[\]()+]*$/) { push @{ $runs[-1] }, $lits[$k][0] } else { push @runs, [$lits[$k][0]] }
  }
  for my $r (@runs) { analyze(join(' ', @$r), $q, $d + 1) if @$r > 1 }
}

# Runner prefixes: the command they run, or ().
sub runner {
  my @w = @_;
  my $c = base($w[0]);
  my $skip = sub { my ($i, $witharg) = @_; while ($i < @w && $w[$i] =~ /^-/) { my $o = $w[$i++]; last if $o eq '--'; $i++ if $o =~ $witharg } return @w[$i .. $#w] };
  return @w[2 .. $#w] if $c eq 'bundle' && @w > 2 && $w[1] eq 'exec';
  return $skip->(1, qr/^(?:-p|--package)$/) if $c =~ /^(?:npx|bunx|pnpx)$/;
  return $skip->(2, qr/^$/) if $c =~ /^(?:pnpm|yarn)$/ && @w > 2 && $w[1] =~ /^(?:dlx|exec)$/;
  return $skip->(2, qr/^(?:-p|--package)$/) if $c eq 'npm' && @w > 2 && $w[1] =~ /^(?:exec|x)$/;
  return @w[2 .. $#w] if $c eq 'dart' && @w > 2 && $w[1] eq 'run';
  if ($c eq 'fvm' && @w > 1) {
    return @w[1 .. $#w] if $w[1] =~ /^(?:flutter|dart)$/;
    return @w[2 .. $#w] if $w[1] eq 'exec';
    return @w[3 .. $#w] if $w[1] eq 'spawn';
  }
  return @w[2 .. $#w] if $c =~ /^(?:rbenv|asdf|rtx|direnv)$/ && @w > 2 && $w[1] eq 'exec';
  return $skip->(2, qr/^$/) if $c eq 'mise' && @w > 2 && $w[1] =~ /^(?:exec|x)$/;
  return $skip->(2, qr/^$/) if $c =~ /^(?:poetry|uv|pipenv|pdm|pipx|volta)$/ && @w > 2 && $w[1] eq 'run';
  return $skip->(1, qr/^-{1,2}(?:sdk|toolchain)$/) if $c eq 'xcrun';
  return ();
}

sub command {
  my ($q, $d, $stdin, @all) = @_;
  my (%alias, @w, @redir);
  for (my $k = 0; $k < @all; $k++) {    # redirections move to the end of the line
    my $x = $all[$k];
    next if $x eq '<<HEREDOC';
    if ($x =~ /^\d*<<<$/) { $k++; next }
    next if $x =~ /^\d*<<</;
    if ($x =~ /^\d*(?:>>|>\||<>|&>>|&>|>&|<&|>|<)$/) { push @redir, $x, $all[++$k] // ''; next }
    if ($x =~ /^(\d*(?:>>|&>>|&>|>&|<&|>|<))(.+)$/s) { push @redir, $1, $2; next }
    push @w, $x;
  }
  while (@w) {    # reserved words, assignments, transparent prefixes
    my $c = $w[0];
    my $b = base($c);
    if ($RESERVED{$c}) { shift @w; next }
    if ($c =~ /^[A-Za-z_][A-Za-z0-9_]*\+?=/) { last if @w == 1; shift @w; next }
    if ($b eq 'command') { last if @w > 1 && $w[1] =~ /^-[vV]/; shift @w; shift @w while @w && $w[0] eq '-p'; next }
    if ($b =~ /^(?:builtin|nohup|chronic|unbuffer|noglob)$/) { shift @w; next }
    my %arg = (exec => qr/^-a$/, nice => qr/^-n$/, time => qr/^$/, sudo => qr/^-[ugpChDrtUTR]$/,
      doas => qr/^-[uC]$/, xargs => qr/^(?:-[ILnPsdEa]|--(?:arg-file|delimiter|eof|replace|max-lines|max-args|max-procs|max-chars))$/,
      timeout => qr/^-[sk]$/, gtimeout => qr/^-[sk]$/, stdbuf => qr/^-[ioe]$/, ionice => qr/^-[cnp]$/,
      caffeinate => qr/^-[wt]$/, taskpolicy => qr/^-[cpt]$/);
    if ($arg{$b}) {
      shift @w;
      my $rep;
      while (@w && $w[0] =~ /^-/) {
        my $o = shift @w;
        last if $o eq '--';
        $rep = '{}' if $b eq 'xargs' && $o =~ /^(?:-i|--replace)$/;
        $rep = $1 if $b eq 'xargs' && $o =~ /^(?:-I|--replace=)(.+)$/;
        my $v = $o =~ $arg{$b} ? shift(@w) : undef;
        $rep = $v if $b eq 'xargs' && $o eq '-I';
      }
      shift @w if $b =~ /timeout$/ && @w && $w[0] =~ /^[0-9.]+[smhd]?$/;
      if ($b eq 'xargs' && defined $stdin) {    # xargs feeds its input as arguments
        my @in = words_of($stdin);
        if (defined $rep) { my $j = join(' ', @in); s/\Q$rep\E/$j/g for @w } else { push @w, @in }
        $stdin = undef;
      }
      next;
    }
    if ($b eq 'env') {
      shift @w;
      while (@w && $w[0] =~ /^-|^[A-Za-z_][A-Za-z0-9_]*=/) {
        my $o = shift @w;
        last if $o eq '--';
        if ($o =~ /^-[uCP]$/) { shift @w }
        elsif ($o =~ /^(?:-S|--split-string=?)(.*)$/s) { unshift @w, words_of(length $1 ? $1 : shift(@w)); last }
      }
      next;
    }
    last;
  }
  return unless @w;
  my $b = base($w[0]);
  if ($b =~ /^git-(push|merge|send-pack)$/) { splice @w, 0, 1, 'git', $1; $b = 'git' }
  emit($q, @w, @redir) unless $b eq 'git';

  if (($b eq 'lumenparty' || $b eq 'wol') && @w > 1 && $w[1] eq 'slow') { analyze(join(' ', @w[2 .. $#w]), 1, $d + 1); return }
  if ($b eq 'slow.sh') { analyze(join(' ', @w[1 .. $#w]), 1, $d + 1); return }
  if ($b eq 'eval') { analyze(join(' ', @w[1 .. $#w]), $q, $d + 1); return }
  if ($b eq 'watch') { shift @w; while (@w && $w[0] =~ /^-/) { my $o = shift @w; shift @w if $o =~ /^-[nq]$/ } analyze(join(' ', @w), $q, $d + 1); return }
  if ($b eq 'busybox' && @w > 1) { command($q, $d, $stdin, @w[1 .. $#w]); return }
  if ($b eq 'find') {
    for (my $i = 1; $i < @w; $i++) {
      next unless $w[$i] =~ /^-(?:exec|execdir|ok|okdir)$/;
      my @sub;
      push @sub, $w[$i] while ++$i < @w && $w[$i] ne ';' && $w[$i] ne '+';
      command($q, $d + 1, undef, @sub) if @sub;
    }
    return;
  }
  if ($SHELL{$b}) {
    my ($cflag, $sflag, $i) = (0, 0, 1);
    while ($i < @w && $w[$i] =~ /^[-+]./) {
      my $o = $w[$i++];
      last if $o eq '--';
      if ($o =~ /^--(?:rcfile|init-file)$/) { $i++; next }
      next if $o =~ /^--/;
      $cflag = 1 if $o =~ /^-\w*c/;
      $sflag = 1 if $o =~ /^-\w*s/;
      $i++ if $o =~ /^[-+]\w*o/;
    }
    if ($cflag) { analyze($w[$i], $q, $d + 1) if $i < @w; return }
    if ($i < @w && !$sflag && $w[$i] ne '-') {
      my $s = base($w[$i]);
      command($q, $d + 1, $stdin, @w[$i .. $#w]) if $s =~ /^(?:slow\.sh|lumenparty|wol)$/;
      return;    # a script file: out of sight
    }
    analyze($stdin, $q, $d + 1);
    return;
  }
  if ($b =~ $INTERP) { code($q, $d, $_) for @w[1 .. $#w], $stdin; return }
  if ($b eq 'git') {
    my ($i, $dir) = (1, undef);
    while ($i < @w && $w[$i] =~ /^-/) {
      my $o = $w[$i++];
      if ($o eq '-C') { $dir = $w[$i++] }
      elsif ($o eq '-c') { my $kv = $w[$i++] // ''; $alias{lc $1} = $2 if $kv =~ /^alias\.([^=]+)=(.*)$/si }
      elsif ($o =~ /^--(?:git-dir|work-tree|namespace|exec-path|config-env|super-prefix|list-cmds|attr-source)$/) { $i++ }
    }
    my @rest = @w[$i .. $#w];
    if (@rest && $rest[0] eq 'config') {    # an alias set earlier in the same line
      my @a = grep { !/^-/ } @rest[1 .. $#rest];
      $line_alias{ lc $1 } = $a[1] if @a > 1 && $a[0] =~ /^alias\.(.+)$/i;
    }
    for (1 .. 5) {
      last unless @rest && !$GIT_BUILTIN{ $rest[0] };
      my $k = lc $rest[0];
      my $exp = exists $alias{$k} ? $alias{$k} : exists $line_alias{$k} ? $line_alias{$k} : git_alias($rest[0], $dir);
      last unless defined $exp;
      if ($exp =~ s/^!//) { emit($q, 'git', @rest); analyze(join(' ', $exp, map { sq($_) } @rest[1 .. $#rest]), $q, $d + 1); return }
      splice @rest, 0, 1, words_of($exp);
    }
    emit($q, 'git', @rest, @redir);
    return;
  }
  my @r = runner(@w);
  if (@r) {    # a package spec runs its binary: eas-cli@latest -> eas
    my %bin = ('eas-cli' => 'eas', 'firebase-tools' => 'firebase', '@shorebird/cli' => 'shorebird', 'expo-cli' => 'expo');
    $r[0] =~ s/^(\@?[^@]+)\@.*$/$1/;
    $r[0] = $bin{ $r[0] } // $r[0];
    command($q, $d + 1, $stdin, @r);
  }
}

analyze(do { local $/; <STDIN> }, 0, 0);
print "$_\n" for @out;
__END__
PERL
