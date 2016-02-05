#!/usr/bin/env perl
use Applify;

option bool => i => 'Replace source';
option str => eopm => 'End of perl module marker', '^1;';

documentation 'App::podify';

app {
  my $self        = shift;
  my $perl_module = shift or die $self->_script->print_help, "Module is required.\n";
  my $eopm        = $self->eopm;
  my $code        = '';
  my $data        = '';
  my ($IN, $OUT, @pod, %has);

  open $IN, '<', $perl_module or die "Read $perl_module: $!\n";
  $eopm = qr{$eopm};

  while (<$IN>) {
    my $pod;
    $has{data}++         if /^__DATA__\s/;
    $has{pod_encoding}++ if /^=encoding\s/;
    $has{attr}{$1} = $1 if /^has\s+([a-z]\w*)/;
    $has{sub}{$1}  = $1 if /^sub\s+([a-z]\w*)/;
    $has{pod}{$1}  = $1 if /^=head2\s([a-z]\w*)/;
    $has{package} ||= $1 if /^package\s+([^\s;]+)/;
    $has{version} ||= $1 if /^VERSION.*([\d\.]+)/;
    $pod = push @pod, $_ if /^=head/ .. /=cut/;
    $code .= $_ unless $has{data} or $pod or $_ =~ $eopm;
    $data .= $_ if $has{data};
  }

  delete $has{attr}{$_} or delete $has{sub}{$_} for keys %{$has{pod} || {}};

  $code =~ s!\n\n\n!\n\n!g;
  $code =~ s!\nuse!use!s;

  unless (@pod) {
    push @pod, sprintf "=head1 NAME\n\n%s - TODO\n\n", $has{package} || 'No::Package';
    push @pod, sprintf "=head1 VERSION\n\n$%s\n\n", $has{version} if $has{version};
    push @pod, sprintf "=head1 SYNOPSIS\n\nTODO\n\n";
    push @pod, sprintf "=head1 DESCRIPTION\n\nTODO\n\n";
    push @pod, sprintf "=head1 ATTRIBUTES\n\n";
    push @pod, sprintf "=head2 %s\n\n", delete $has{attr}{$_} for sort keys %{$has{attr} || {}};
    push @pod, sprintf "=head1 METHODS\n\n";
    push @pod, sprintf "=head2 %s\n\n", delete $has{sub}{$_}  for sort keys %{$has{sub}  || {}};
    push @pod, sprintf "=head1 AUTHOR\n\n%s\n\n", (getpwuid $<)[6] || (getpwuid $<)[0];
    push @pod, sprintf "=head1 COPYRIGHT AND LICENSE\n\nTODO\n\n";
    push @pod, sprintf "=head1 SEE ALSO\n\nTODO\n\n";
  }

  if (grep {/^-i/} @ARGV) {
    open $OUT, '>', $perl_module or die "Write $perl_module: $!\n";
  }
  else {
    $OUT = \*STDOUT;
  }

  print $OUT "${code}1;\n\n";
  print $OUT "=encoding utf8\n\n" unless $has{pod_encoding};
  print $OUT $_ for grep { !/^=cut/ } @pod;
  print $OUT "=cut\n";
  print $OUT "\n$data" if $has{data};

  for my $section (qw(attr sub)) {
    for my $name (keys %{$has{$section} || {}}) {
      warn "Missing $section in pod: $name\n";
    }
  }
};
