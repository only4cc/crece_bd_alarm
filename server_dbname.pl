#
# Objetivo: Obtiene los nombres de las Bases de Datos (con el tag "mssql") en un servidor especifico
#

use strict;
use warnings;

use Search::Elasticsearch;
use Config::Tiny;
use Data::Dumper;

my $DEBUG      = 1;
my $MAX_POINTS = 1000;
 
print "Obteniendo lista de servidores ...\n" if $DEBUG;

my $config = Config::Tiny->new;
$config    = Config::Tiny->read( 'crece_alarm.conf' );
		
# Parametros de busqueda
my $serverid   = $config->{principal}->{serverid}  || '*';   # '*' Todos los servers
my $index_name = $config->{principal}->{indexname};  
my $nodo       = $config->{principal}->{nodos} || 'http://10.36.16.30:9200/'; #'http://logs.e-contact.cl:9200/';   # lab  # 'http://srv0018.e-contact.cl:9200/';   # dev

#print "serverid:$serverid\nindex_name:$index_name\nnodo:$nodo\n";
#exit;

my $e = Search::Elasticsearch->new( nodes => [ $nodo, ], trace_to => 'Stderr' );
my $query = "mssql";

# Ejecuta la consulta 
my $results = $e->search(
    index => $index_name,
	size => $MAX_POINTS,
    body  => {
        query => {
            query_string => { "query" => $query  }
        }
    }
);

#print "lista de servidores recuperada\n" if $DEBUG;
#print Dumper $results if $DEBUG;

# Recorre respuesta, llena observaciones para calculo estad. y despliega
my %puntos;
my $dbname;
print "\nResultado de la consulta : $query\n" if $DEBUG;
foreach (my $i=0; $i< scalar @{$results->{hits}->{hits}}; ++$i ) {
	$serverid = $results->{hits}->{hits}->[$i]->{_source}->{serverid};
	$dbname   = $results->{hits}->{hits}->[$i]->{_source}->{dbid};
	$puntos{ $serverid."|".$dbname } = 1 if ( $serverid and $dbname );
	print $serverid ."\t" . $dbname if $DEBUG;
}

foreach my $k ( keys %puntos ) {
	print $k."\n";
}
