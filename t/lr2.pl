#!usr/bin/perl
# Ejemplo de uso de Regresion lineal (monovariada k=1)
#
use Statistics::Regression;
use strict;
use warnings;

my $reg=Statistics::Regression->new( "Titulo", ["Intercepcion", "Pendiente"]); 

my $k=1;
my $NUMPOINTS=100;
foreach ( my $i=1; $i<$NUMPOINTS; ++$i ) {
    $reg->include(rand(4), [$k, $i]);
}

$reg->print;
