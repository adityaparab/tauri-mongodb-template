import Table from '@mui/material/Table'
import TableBody from '@mui/material/TableBody'
import TableCell from '@mui/material/TableCell'
import TableContainer from '@mui/material/TableContainer'
import TableHead from '@mui/material/TableHead'
import TableRow from '@mui/material/TableRow'
import type { BuildRecord } from '../../types'
import BuildTableRow from './BuildTableRow'

interface BuildTableProps {
  records: BuildRecord[]
  downloadingUuid: string | null
  onDownload: (record: BuildRecord) => void
}

export default function BuildTable({ records, downloadingUuid, onDownload }: BuildTableProps) {
  return (
    <TableContainer>
      <Table stickyHeader size="small" aria-label="Submitted UUID builds">
        <TableHead>
          <TableRow>
            <TableCell>UUID</TableCell>
            <TableCell>Status</TableCell>
            <TableCell>Submitted</TableCell>
            <TableCell>Completed</TableCell>
            <TableCell>Artifact</TableCell>
            <TableCell align="right">Actions</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          {records.map((record) => (
            <BuildTableRow
              key={record.id}
              record={record}
              isDownloading={downloadingUuid === record.uuid}
              onDownload={onDownload}
            />
          ))}
        </TableBody>
      </Table>
    </TableContainer>
  )
}