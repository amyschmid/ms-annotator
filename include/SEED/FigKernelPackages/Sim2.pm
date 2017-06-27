package Sim2;

sub id1 {
    my ($sim) = @_;
    return $sim->[0];
}

sub id2 {
    my ($sim) = @_;
    return $sim->[1];
}

sub dist {
    my ($sim) = @_;
    return $sim->[2];
}
sub iden {
    my ($sim) = @_;
    return undef;
}

sub ali_ln {
    my ($sim) = @_;
    return undef;
}

sub mismatches {
    my ($sim) = @_;
    return undef;
}
sub b1 {
    my ($sim) = @_;
    return $sim->[4];
}

sub e1 {
    my ($sim) = @_;
    return $sim->[5];
}

sub loc1 {
    my($sim) = @_;

    return $sim->[6];
}

sub loc2 {
    my($sim) = @_;

    return $sim->[10];
}

sub b2 {
    my ($sim) = @_;
    return $sim->[8];
}

sub e2 {
    my ($sim) = @_;
    return $sim->[9];
}

sub psc {
    my ($sim) = @_;
    return undef;
}

sub bsc {
    my ($sim) = @_;
    return undef;
}

sub bit_score {
    my ($sim) = @_;
    return $sim->bsc;
}

sub nbsc {
    my($sim) = @_;
    return undef;
}

sub ln1 {
    my ($sim) = @_;
    return $sim->[3];
}

sub ln2 {
    my ($sim) = @_;
    return $sim->[7];
}

sub tool {
    my ($sim) = @_;
    return 'treesim';
}

1;
