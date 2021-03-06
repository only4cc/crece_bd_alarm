use strict;
use warnings;
use Excel::Writer::XLSX;

# Ubicacion de "Calc" de Open Office (compatible con excel)
my $pgm = 'C:\\Program Files (x86)\\LibreOffice 5\\program\\scalc.exe';

my $chartname = 'C:\\tmp\\chart.xlsx';
my $workbook  = Excel::Writer::XLSX->new( $chartname );
my $worksheet = $workbook->add_worksheet();
my $chart     = $workbook->add_chart( type => 'line' );

my $data = get_data();
my $num_cells = ((( length $data->[0] ) / 2 ) - 1);

$chart->add_series(
    categories => '=Sheet1!$A$2:$A$'.$num_cells,
    values     => '=Sheet1!$B$2:$B$'.$num_cells,
);

$chart->set_title( name => 'Crecimiento de la Base de Datos' );
$worksheet->write( 'A1', $data );
$workbook->close()  or die "Error al cerrar: $!";

system($pgm, $chartname);

sub get_data {
    my $rx = [ 'Categoria', 2, 3, 4, 5, 6, 7, 8, 9 ];
    my $ry = [ 'Valor',    1, 4, 5, 2, 1, 5, 10, 8 ],
    my @x = @$rx;
    my $data = [
         $rx, $ry,
    ];
    return $data;
}