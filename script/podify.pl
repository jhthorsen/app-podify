#!/usr/bin/env perl
use Applify;
use if -e '.ship.conf', lib => 'lib';

option bool => i    => 'Replace source',            0;
option str  => eopm => 'End of perl module marker', '^1;';

documentation 'App::podify';

sub check_pod {
  my $self = shift;

  for my $section (qw(attrs subs)) {
    for my $name (keys %{$self->{$section} || {}}) {
      warn "Missing $section in pod: $name\n";
    }
  }

  return $self;
}

sub generate {
  my ($self, $OUT) = @_;

  $self->{pod} = $self->pod_template unless @{$self->{pod}};

  if ($self->i) {
    open $OUT, '>', $self->{perl_module} or die "Write $self->{perl_module}: $!\n";
  }
  elsif (!$OUT) {
    $OUT = \*STDOUT;
  }

  my $code = join '', @{$self->{code}};
  $code =~ s!\n\n\n!\n\n!g;
  $code =~ s!\n+use!\nuse!s;
  $code =~ s!\n+$!\n\n!;

  print $OUT "${code}1;\n\n";
  print $OUT "=encoding utf8\n\n" unless $self->{pod_has_encoding};
  print $OUT $_ for grep { !/^=cut/ } @{$self->{pod}};
  print $OUT "=cut\n";
  print $OUT "\n" . join '', @{$self->{data}} if @{$self->{data}};
}

sub init {
  my $self = shift;
  $self->{attrs} = {};
  $self->{code}  = [];
  $self->{data}  = [];
  $self->{pod}   = [];
  $self->{subs}  = {};
  $self;
}

sub parse {
  my $self = shift;
  my $eopm = $self->eopm;
  my %has;

  open my $IN, '<', $self->{perl_module} or die "Read $self->{perl_module}: $!\n";
  $eopm = qr{$eopm};

  while (<$IN>) {
    my $pod;
    next if /^=encoding\s/;
    $self->{attrs}{$1}      = $1 if /^has\s+([a-z]\w*)/;
    $self->{subs}{$1}       = $1 if /^sub\s+([a-z]\w*)/;
    $self->{documented}{$1} = $1 if /^=head2\s([a-z]\w*)/;
    $self->{module_name}    ||= $1 if /^package\s+([^\s;]+)/;
    $self->{module_version} ||= $1 if /^VERSION.*([\d\.]+)/;
    $pod = push @{$self->{pod}}, $_ if /^=head/ .. /=cut/;
    push @{$self->{data}}, $_ if @{$self->{data}} or /^__DATA__$/;
    push @{$self->{code}}, $_ unless @{$self->{data}} or $pod or $_ =~ $eopm;
  }

  return $self;
}

sub pod_template {
  my $self = shift;

  return [
    sprintf("=head1 NAME\n\n%s - TODO\n\n", $self->{module_name} || 'Unknown'),
    $self->{module_version} ? printf("=head1 VERSION\n\n$%s\n\n", $self->{module_version}) : (),
    sprintf("=head1 SYNOPSIS\n\nTODO\n\n"),
    sprintf("=head1 DESCRIPTION\n\nTODO\n\n"),
    sprintf("=head1 ATTRIBUTES\n\n"),
    map({ sprintf "=head2 %s\n\n", delete $self->{attrs}{$_} } sort keys %{$self->{attrs} || {}}),
    sprintf("=head1 METHODS\n\n"),
    map({ sprintf "=head2 %s\n\n", delete $self->{subs}{$_} } sort keys %{$self->{subs} || {}}),
    sprintf("=head1 AUTHOR\n\n%s\n\n", (getpwuid $<)[6] || (getpwuid $<)[0]),
    sprintf("=head1 COPYRIGHT AND LICENSE\n\nTODO\n\n"),
    sprintf("=head1 SEE ALSO\n\nTODO\n\n"),
  ];
}

sub post_process {
  my $self = shift;
  delete $self->{attrs}{$_} or delete $self->{subs}{$_} for keys %{$self->{documented}};
}

app {
  my $self = shift->init;

  $self->{perl_module} = shift or die $self->_script->print_help, "Module is required.\n";
  $self->parse;
  $self->post_process;
  $self->generate;
  $self->check_pod;

  return 0;
};
