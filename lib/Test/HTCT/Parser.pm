package Test::HTCT::Parser;
use strict;
use warnings;
no warnings 'utf8';
our $VERSION = '3.0';

our @EXPORT = qw(for_each_test);

sub import ($;@) {
  my $from_class = shift;
  my ($to_class, $file, $line) = caller;
  no strict 'refs';
  for (@_ ? @_ : @{$from_class . '::EXPORT'}) {
    my $code = $from_class->can ($_)
        or die qq{"$_" is not exported by the $from_class module at $file line $line};
    *{$to_class . '::' . $_} = $code;
  }
} # import

sub for_each_test ($$$) {
  my $file_name = shift;
  my $field_props = shift; # {$field_name => {is_prefixed, is_list}}
  my $test_code = shift;

  print STDERR "# $file_name\n";

  my @tests;
  {
    open my $file, '<:encoding(utf8)', $file_name or die "$0: $file_name: $!";
    local $/ = undef;
    my $content = <$file>;
    $content =~ s/\x0D\x0A/\x0A/g;
    $content =~ tr/\x0D/\x0A/;
    $content =~ s/^\x0A*#//;
    $content =~ s/\x0A+\z//;
    @tests = split /\x0A\x0A#/, $content;
  }

  for (@tests) {
    my %test;
    for my $v (split /\x0A#/, $_) {
      my $field_name = '';
      my @field_opt;
      if ($v =~ s/^([A-Za-z0-9-]+)//) {
        $field_name = $1;
      }
      if ($v =~ s/^([^\x0A]*)(?:\x0A|$)//) {
        push @field_opt, grep {length $_} split /[\x09\x20]+/, $1;
      }

      if ($field_props->{$field_name}->{is_prefixed}) {
        $v =~ s/^\| //;
        $v =~ s/\x0A\| /\x0A/g;
      }
      if ($field_props->{$field_name}->{is_list}) {
        my @v = split /\x0A/, $v, -1;
        my $field_escaped = (@field_opt and $field_opt[-1] eq 'escaped');
        if ($field_escaped) {
          pop @field_opt;
          for (@v) {
            s/\\u([0-9A-Fa-f]{4})/chr hex $1/ge;
            s/\\U([0-9A-Fa-f]{8})/chr hex $1/ge;
          }
        }

        if ($field_props->{$field_name}->{multiple}) {
          $test{$field_name} ||= [];
          push @{$test{$field_name}}, [\@v, \@field_opt];
        } else {
          if (defined $test{$field_name}) {
            warn qq[Duplicate #$field_name field (value "$v")];
          } else {
            $test{$field_name} = [\@v, \@field_opt];
          }
        }
      } else {
        my $field_escaped = (@field_opt and $field_opt[-1] eq 'escaped');
        if ($field_escaped) {
          pop @field_opt;
          $v =~ s/\\u([0-9A-Fa-f]{4})/chr hex $1/ge;
          $v =~ s/\\U([0-9A-Fa-f]{8})/chr hex $1/ge;
        }

        if ($field_props->{$field_name}->{multiple}) {
          $test{$field_name} ||= [];
          push @{$test{$field_name}}, [$v, \@field_opt];
        } else {
          if (defined $test{$field_name}) {
            warn qq[Duplicate #$field_name field (value "$v")];
          } else {
            $test{$field_name} = [$v, \@field_opt];
          }
        }
      }
    }

    $test_code->(\%test);
  }
} # execute_test

1;

=head1 LICENSE

Copyright 2007-2015 Wakaba <wakaba@suikawiki.org>.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
